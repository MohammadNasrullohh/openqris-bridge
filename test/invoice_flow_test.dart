import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:qris_bridge/core/emvco/crc16.dart';
import 'package:qris_bridge/core/manager/invoice_manager.dart';
import 'package:qris_bridge/core/manager/unique_code_allocator.dart';
import 'package:qris_bridge/core/models/invoice.dart';
import 'package:qris_bridge/core/models/provider_type.dart';
import 'package:qris_bridge/core/models/webhook_payload.dart';
import 'package:qris_bridge/core/parsers/notification_parser_registry.dart';
import 'package:qris_bridge/core/server/bridge_server.dart';

void main() {
  const sampleStaticWithoutCrc =
      '00020101021126610016ID.CO.SHOPEE.WWW01189360099900000000000208123456780303UMI5204541153033605802ID5914WARUNG DJ TEST6007JAKARTA6105123456304';
  final sampleStaticQris =
      '$sampleStaticWithoutCrc${Crc16Ccitt.computeHex(sampleStaticWithoutCrc)}';

  group('Invoice and Matching Flow Tests', () {
    test('End-to-end 25k transaction flow with DANA notification', () {
      final allocator = UniqueCodeAllocator(
        strategy: UniqueCodeStrategy.sequential,
        minCode: 142,
        maxCode: 999,
      );
      final manager = InvoiceManager(allocator: allocator);
      final registry = NotificationParserRegistry();

      Invoice? paidEventInvoice;
      manager.addOnPaidListener((inv) {
        paidEventInvoice = inv;
      });

      // 1. Create invoice for Rp 25.000
      final invoice = manager.createInvoice(
        baseAmount: 25000,
        staticQris: sampleStaticQris,
        referenceId: 'ORDER-25K',
      );

      expect(invoice.baseAmount, 25000.0);
      expect(invoice.uniqueCode, 142);
      expect(invoice.totalAmount, 25142.0);
      expect(invoice.status, InvoiceStatus.pending);
      expect(invoice.qrisRaw.contains('540525142'), isTrue);

      // 2. Incoming notification arrives from DANA on merchant phone
      final incomingMutation = registry.parseNotification(
        packageName: 'id.dana',
        title: 'DANA Bisnis',
        message: 'Berhasil menerima saldo sebesar Rp 25.142 dari BUDI SETIAWAN.',
      );

      expect(incomingMutation, isNotNull);
      expect(incomingMutation!.amount, 25142.0);
      expect(incomingMutation.provider, ProviderType.dana);

      // 3. Process mutation into invoice manager
      final matchedInvoice = manager.processIncomingMutation(incomingMutation);

      expect(matchedInvoice, isNotNull);
      expect(matchedInvoice!.status, InvoiceStatus.paid);
      expect(matchedInvoice.paidAt, isNotNull);
      expect(paidEventInvoice, isNotNull);
      expect(paidEventInvoice!.id, invoice.id);

      // 4. Verify Webhook payload and HMAC signature
      const secret = 'my_merchant_secret_123';
      final webhook = WebhookPayload(
        event: 'invoice.paid',
        timestamp: DateTime.now(),
        invoice: matchedInvoice,
        mutation: incomingMutation,
      );

      final signature = webhook.computeSignature(secret);
      expect(signature.isNotEmpty, isTrue);

      final isValid = WebhookPayload.verifySignature(
        payloadJson: webhook.toJsonString(),
        secretKey: secret,
        expectedSignature: signature,
      );
      expect(isValid, isTrue);

      manager.dispose();
    });

    test('Embedded BridgeServer REST endpoints', () async {
      final manager = InvoiceManager();
      final registry = NotificationParserRegistry();
      final server = BridgeServer(
        invoiceManager: manager,
        parserRegistry: registry,
        getStaticQris: () => sampleStaticQris,
        port: 0, // ephemeral port for test
      );

      final actualPort = await server.start();
      expect(server.isRunning, isTrue);

      final client = http.Client();

      // Health endpoint
      final healthRes = await client.get(Uri.parse('http://127.0.0.1:$actualPort/health'));
      expect(healthRes.statusCode, 200);
      final healthJson = jsonDecode(healthRes.body);
      expect(healthJson['status'], 'ok');

      // Create invoice via REST
      final createRes = await client.post(
        Uri.parse('http://127.0.0.1:$actualPort/api/v1/invoices'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': 25000,
          'reference_id': 'REST-ORDER-1',
        }),
      );
      expect(createRes.statusCode, 201);
      final createJson = jsonDecode(createRes.body);
      expect(createJson['success'], isTrue);
      final invoiceData = createJson['data'];
      final invoiceId = invoiceData['id'];
      final totalAmount = (invoiceData['total_amount'] as num).toDouble();

      // Simulate payment mutation via REST
      final simRes = await client.post(
        Uri.parse('http://127.0.0.1:$actualPort/api/v1/mutations/simulate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': totalAmount,
          'provider': 'ShopeePay',
          'sender_name': 'PEMBELI VIA REST',
        }),
      );
      expect(simRes.statusCode, 200);
      final simJson = jsonDecode(simRes.body);
      expect(simJson['matched'], isTrue);
      expect(simJson['matched_invoice']['id'], invoiceId);
      expect(simJson['matched_invoice']['status'], 'PAID');

      // Verify invoice status via GET /api/v1/invoices/<id>
      final getRes = await client.get(Uri.parse('http://127.0.0.1:$actualPort/api/v1/invoices/$invoiceId'));
      expect(getRes.statusCode, 200);
      final getJson = jsonDecode(getRes.body);
      expect(getJson['data']['status'], 'PAID');

      await server.stop();
      manager.dispose();
      client.close();
    });
  });
}
