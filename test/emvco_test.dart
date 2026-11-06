import 'package:flutter_test/flutter_test.dart';
import 'package:qris_bridge/core/emvco/crc16.dart';
import 'package:qris_bridge/core/emvco/qris_parser.dart';
import 'package:qris_bridge/core/emvco/qris_converter.dart';

void main() {
  group('EMVCo QRIS Engine Tests', () {
    // Standard static QRIS base string
    const sampleStaticWithoutCrc =
        '00020101021126610016ID.CO.SHOPEE.WWW01189360099900000000000208123456780303UMI5204541153033605802ID5914WARUNG DJ TEST6007JAKARTA6105123456304';

    test('CRC16 calculation produces valid 4-character hex', () {
      final crc = Crc16Ccitt.computeHex(sampleStaticWithoutCrc);
      expect(crc.length, 4);
      expect(RegExp(r'^[0-9A-F]{4}$').hasMatch(crc), isTrue);

      final fullStaticQris = '$sampleStaticWithoutCrc$crc';
      expect(Crc16Ccitt.isValidQrisCrc(fullStaticQris), isTrue);
    });

    test('QrisParser correctly parses static QRIS tags', () {
      final crc = Crc16Ccitt.computeHex(sampleStaticWithoutCrc);
      final fullStaticQris = '$sampleStaticWithoutCrc$crc';

      final payload = QrisParser.parse(fullStaticQris);
      expect(payload.isValidCrc, isTrue);
      expect(payload.payloadFormatIndicator, '01');
      expect(payload.pointOfInitiationMethod, '11');
      expect(payload.isStatic, isTrue);
      expect(payload.isDynamic, isFalse);
      expect(payload.merchantName, 'WARUNG DJ TEST');
      expect(payload.merchantCity, 'JAKARTA');
      expect(payload.postalCode, '12345');
      expect(payload.countryCode, 'ID');
      expect(payload.transactionCurrency, '360');
      expect(payload.transactionAmount, isNull);
    });

    test('QrisConverter converts static to dynamic with Tag 54 injected', () {
      final crc = Crc16Ccitt.computeHex(sampleStaticWithoutCrc);
      final fullStaticQris = '$sampleStaticWithoutCrc$crc';

      // Convert to dynamic with 25,142 IDR
      final dynamicQris = QrisConverter.convertToDynamic(
        staticQris: fullStaticQris,
        amount: 25142,
        invoiceNumber: 'INV-1001',
      );

      // Verify CRC of the dynamic QRIS
      expect(Crc16Ccitt.isValidQrisCrc(dynamicQris), isTrue);

      // Parse dynamic QRIS
      final dynamicPayload = QrisParser.parse(dynamicQris);
      expect(dynamicPayload.isValidCrc, isTrue);
      expect(dynamicPayload.pointOfInitiationMethod, '12');
      expect(dynamicPayload.isDynamic, isTrue);
      expect(dynamicPayload.transactionAmount, 25142.0);
      expect(dynamicPayload.merchantName, 'WARUNG DJ TEST');

      // Tag 62 should have bill number
      expect(dynamicPayload.tags.containsKey('62'), isTrue);
      expect(dynamicPayload.tags['62']!.value.contains('INV-1001'), isTrue);

      // Verification helper
      expect(QrisConverter.verifyDynamicQris(dynamicQris, 25142), isTrue);
      expect(QrisConverter.verifyDynamicQris(dynamicQris, 25000), isFalse);
    });
  });
}
