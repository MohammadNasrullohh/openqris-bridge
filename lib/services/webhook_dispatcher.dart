import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/models/invoice.dart';
import '../core/models/payment_mutation.dart';
import '../core/models/webhook_payload.dart';

class WebhookDeliveryLog {
  final String id;
  final String url;
  final String event;
  final int? statusCode;
  final String? responseBody;
  final String? error;
  final int durationMs;
  final DateTime attemptedAt;
  final bool isSuccess;

  const WebhookDeliveryLog({
    required this.id,
    required this.url,
    required this.event,
    this.statusCode,
    this.responseBody,
    this.error,
    required this.durationMs,
    required this.attemptedAt,
    required this.isSuccess,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'event': event,
        'status_code': statusCode,
        'response_body': responseBody,
        'error': error,
        'duration_ms': durationMs,
        'attempted_at': attemptedAt.toIso8601String(),
        'is_success': isSuccess,
      };
}

/// Dispatches signed HTTP webhooks to the merchant's backend.
class WebhookDispatcher {
  String webhookUrl;
  String secretKey;
  bool isEnabled;
  final http.Client _client;
  final List<WebhookDeliveryLog> _logs = [];

  WebhookDispatcher({
    this.webhookUrl = '',
    this.secretKey = '',
    this.isEnabled = true,
    http.Client? client,
  }) : _client = client ?? http.Client();

  List<WebhookDeliveryLog> get deliveryLogs => List.unmodifiable(_logs.reversed);

  /// Dispatches payment confirmation webhook to merchant backend with retries.
  Future<bool> dispatchInvoicePaid({
    required Invoice invoice,
    PaymentMutation? mutation,
    int maxRetries = 3,
  }) async {
    if (!isEnabled || webhookUrl.trim().isEmpty) {
      return false;
    }

    final now = DateTime.now();
    final payload = WebhookPayload(
      event: 'invoice.paid',
      timestamp: now,
      invoice: invoice,
      mutation: mutation,
    );

    final payloadJson = payload.toJsonString();
    final signature = payload.computeSignature(secretKey);

    return _sendWithRetry(
      url: webhookUrl.trim(),
      event: 'invoice.paid',
      payloadJson: payloadJson,
      signature: signature,
      timestamp: now,
      maxRetries: maxRetries,
    );
  }

  /// Sends a test ping to verify connectivity.
  Future<WebhookDeliveryLog> sendTestPing() async {
    final now = DateTime.now();
    final dummyInvoice = Invoice(
      id: 'TEST-PING-001',
      baseAmount: 25000,
      uniqueCode: 142,
      totalAmount: 25142,
      qrisRaw: '',
      status: InvoiceStatus.paid,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
      paidAt: now,
    );

    final payload = WebhookPayload(
      event: 'test.ping',
      timestamp: now,
      invoice: dummyInvoice,
    );

    final payloadJson = payload.toJsonString();
    final signature = payload.computeSignature(secretKey);

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client.post(
        Uri.parse(webhookUrl.trim()),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'OpenQrisBridge/1.0',
          'X-Signature': signature,
          'X-Timestamp': now.toIso8601String(),
          'X-Event': 'test.ping',
        },
        body: payloadJson,
      ).timeout(const Duration(seconds: 10));

      stopwatch.stop();
      final log = WebhookDeliveryLog(
        id: 'log-${now.millisecondsSinceEpoch}',
        url: webhookUrl.trim(),
        event: 'test.ping',
        statusCode: response.statusCode,
        responseBody: response.body.length > 200 ? response.body.substring(0, 200) : response.body,
        durationMs: stopwatch.elapsedMilliseconds,
        attemptedAt: now,
        isSuccess: response.statusCode >= 200 && response.statusCode < 300,
      );
      _logs.add(log);
      return log;
    } catch (e) {
      stopwatch.stop();
      final log = WebhookDeliveryLog(
        id: 'log-${now.millisecondsSinceEpoch}',
        url: webhookUrl.trim(),
        event: 'test.ping',
        error: e.toString(),
        durationMs: stopwatch.elapsedMilliseconds,
        attemptedAt: now,
        isSuccess: false,
      );
      _logs.add(log);
      return log;
    }
  }

  Future<bool> _sendWithRetry({
    required String url,
    required String event,
    required String payloadJson,
    required String signature,
    required DateTime timestamp,
    required int maxRetries,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final stopwatch = Stopwatch()..start();
      try {
        final response = await _client.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'OpenQrisBridge/1.0',
            'X-Signature': signature,
            'X-Timestamp': timestamp.toIso8601String(),
            'X-Event': event,
          },
          body: payloadJson,
        ).timeout(const Duration(seconds: 10));

        stopwatch.stop();
        final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

        _logs.add(WebhookDeliveryLog(
          id: 'log-${DateTime.now().millisecondsSinceEpoch}',
          url: url,
          event: event,
          statusCode: response.statusCode,
          responseBody: response.body.length > 200 ? response.body.substring(0, 200) : response.body,
          durationMs: stopwatch.elapsedMilliseconds,
          attemptedAt: DateTime.now(),
          isSuccess: isSuccess,
        ));

        if (isSuccess) {
          return true;
        }
      } catch (e) {
        stopwatch.stop();
        _logs.add(WebhookDeliveryLog(
          id: 'log-${DateTime.now().millisecondsSinceEpoch}',
          url: url,
          event: event,
          error: e.toString(),
          durationMs: stopwatch.elapsedMilliseconds,
          attemptedAt: DateTime.now(),
          isSuccess: false,
        ));
      }

      if (attempt < maxRetries) {
        await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
      }
    }

    return false;
  }
}
