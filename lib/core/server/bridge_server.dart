import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../manager/invoice_manager.dart';
import '../models/invoice.dart';
import '../models/payment_mutation.dart';
import '../models/provider_type.dart';
import '../parsers/currency_parser.dart';
import '../parsers/notification_parser_registry.dart';

/// Embedded HTTP REST API & WebSocket server that runs directly inside the Flutter app.
class BridgeServer {
  final InvoiceManager invoiceManager;
  final NotificationParserRegistry parserRegistry;
  final String Function() getStaticQris;

  HttpServer? _server;
  int port;
  bool isRunning = false;
  final List<WebSocketChannel> _wsClients = [];

  BridgeServer({
    required this.invoiceManager,
    required this.parserRegistry,
    required this.getStaticQris,
    this.port = 8080,
  }) {
    // Attach listener to broadcast invoice events to WebSocket clients
    invoiceManager.addOnCreatedListener((inv) => _broadcastWs({'event': 'invoice.created', 'data': inv.toJson()}));
    invoiceManager.addOnPaidListener((inv) => _broadcastWs({'event': 'invoice.paid', 'data': inv.toJson()}));
    invoiceManager.addOnExpiredListener((inv) => _broadcastWs({'event': 'invoice.expired', 'data': inv.toJson()}));
    invoiceManager.addOnMutationListener((mut) => _broadcastWs({'event': 'mutation.received', 'data': mut.toJson()}));
  }

  /// Starts the embedded server on [port].
  Future<int> start({int? customPort}) async {
    if (isRunning) return port;
    if (customPort != null) port = customPort;

    final appRouter = Router();

    // Health check
    appRouter.get('/health', (Request request) {
      return _jsonResponse({
        'status': 'ok',
        'service': 'OpenQris Bridge Embedded Server',
        'version': '1.0.0',
        'pending_invoices': invoiceManager.pendingInvoices.length,
        'total_mutations': invoiceManager.allMutations.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    // Create invoice: POST /api/v1/invoices
    appRouter.post('/api/v1/invoices', (Request request) async {
      try {
        final bodyStr = await request.readAsString();
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;

        final amount = (body['amount'] as num?)?.toDouble();
        if (amount == null || amount <= 0) {
          return _jsonResponse({'success': false, 'error': 'Invalid or missing amount'}, status: 400);
        }

        final referenceId = body['reference_id'] as String?;
        final expiryMinutes = (body['expiry_minutes'] as num?)?.toInt() ?? 15;
        final metadata = (body['metadata'] as Map<String, dynamic>?) ?? {};

        final staticQris = getStaticQris();
        final invoice = invoiceManager.createInvoice(
          baseAmount: amount,
          staticQris: staticQris,
          referenceId: referenceId,
          expiryMinutes: expiryMinutes,
          metadata: metadata,
        );

        return _jsonResponse({
          'success': true,
          'data': {
            ...invoice.toJson(),
            'formatted_base_amount': CurrencyParser.formatRupiah(invoice.baseAmount),
            'formatted_total_amount': CurrencyParser.formatRupiah(invoice.totalAmount),
          },
        }, status: 201);
      } catch (e) {
        return _jsonResponse({'success': false, 'error': e.toString()}, status: 400);
      }
    });

    // List invoices: GET /api/v1/invoices
    appRouter.get('/api/v1/invoices', (Request request) {
      final statusParam = request.url.queryParameters['status'];
      var invoices = invoiceManager.allInvoices;

      if (statusParam != null && statusParam.isNotEmpty) {
        final status = InvoiceStatus.fromString(statusParam);
        invoices = invoices.where((i) => i.status == status).toList();
      }

      return _jsonResponse({
        'success': true,
        'count': invoices.length,
        'data': invoices.map((i) => i.toJson()).toList(),
      });
    });

    // Get invoice by ID: GET /api/v1/invoices/<id>
    appRouter.get('/api/v1/invoices/<id>', (Request request, String id) {
      final invoice = invoiceManager.getInvoice(id);
      if (invoice == null) {
        return _jsonResponse({'success': false, 'error': 'Invoice not found'}, status: 404);
      }
      return _jsonResponse({'success': true, 'data': invoice.toJson()});
    });

    // Cancel invoice: POST /api/v1/invoices/<id>/cancel
    appRouter.post('/api/v1/invoices/<id>/cancel', (Request request, String id) {
      final success = invoiceManager.cancelInvoice(id);
      if (!success) {
        return _jsonResponse({'success': false, 'error': 'Invoice cannot be cancelled or not found'}, status: 400);
      }
      return _jsonResponse({'success': true, 'message': 'Invoice cancelled'});
    });

    // List mutations: GET /api/v1/mutations
    appRouter.get('/api/v1/mutations', (Request request) {
      final mutations = invoiceManager.allMutations;
      return _jsonResponse({
        'success': true,
        'count': mutations.length,
        'data': mutations.map((m) => m.toJson()).toList(),
      });
    });

    // Simulate mutation: POST /api/v1/mutations/simulate
    appRouter.post('/api/v1/mutations/simulate', (Request request) async {
      try {
        final bodyStr = await request.readAsString();
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;

        final amount = (body['amount'] as num?)?.toDouble();
        if (amount == null || amount <= 0) {
          return _jsonResponse({'success': false, 'error': 'Invalid amount'}, status: 400);
        }

        final providerStr = body['provider'] as String? ?? 'DANA';
        final provider = ProviderType.fromPackageOrName(providerStr);
        final title = body['title'] as String? ?? 'Simulated Notification';
        final message = body['message'] as String? ?? 'Pembayaran Rp ${amount.toInt()} berhasil';
        final sender = body['sender_name'] as String? ?? 'TEST SENDER';

        final mutation = PaymentMutation(
          id: 'sim-${DateTime.now().millisecondsSinceEpoch}',
          provider: provider,
          amount: amount,
          senderName: sender,
          rawTitle: title,
          rawMessage: message,
          receivedAt: DateTime.now(),
        );

        final matchedInvoice = invoiceManager.processIncomingMutation(mutation);

        return _jsonResponse({
          'success': true,
          'matched': matchedInvoice != null,
          'mutation': mutation.toJson(),
          'matched_invoice': matchedInvoice?.toJson(),
        });
      } catch (e) {
        return _jsonResponse({'success': false, 'error': e.toString()}, status: 400);
      }
    });

    // WebSocket handler: GET /ws
    final wsHandler = webSocketHandler((WebSocketChannel webSocket, [String? protocol]) {
      _wsClients.add(webSocket);
      webSocket.sink.add(jsonEncode({
        'event': 'connected',
        'message': 'Connected to OpenQris Bridge Realtime Stream',
        'timestamp': DateTime.now().toIso8601String(),
      }));

      webSocket.stream.listen(
        (message) {
          // Can receive heartbeat ping
          if (message == 'ping') {
            webSocket.sink.add(jsonEncode({'event': 'pong'}));
          }
        },
        onDone: () => _wsClients.remove(webSocket),
        onError: (_) => _wsClients.remove(webSocket),
      );
    });

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addHandler((Request request) {
      if (request.url.path == 'ws') {
        return wsHandler(request);
      }
      return appRouter(request);
    });

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    isRunning = true;
    return _server!.port;
  }

  /// Stops the embedded server
  Future<void> stop() async {
    for (final client in _wsClients) {
      try {
        client.sink.close();
      } catch (_) {}
    }
    _wsClients.clear();

    await _server?.close(force: true);
    _server = null;
    isRunning = false;
  }

  void _broadcastWs(Map<String, dynamic> data) {
    final encoded = jsonEncode(data);
    for (final client in List.of(_wsClients)) {
      try {
        client.sink.add(encoded);
      } catch (_) {
        _wsClients.remove(client);
      }
    }
  }

  Response _jsonResponse(Map<String, dynamic> json, {int status = 200}) {
    return Response(
      status,
      body: jsonEncode(json),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, X-Requested-With',
      },
    );
  }

  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, PUT, DELETE',
            'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, X-Requested-With',
          });
        }
        final response = await innerHandler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, PUT, DELETE',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization, X-Requested-With',
        });
      };
    };
  }
}
