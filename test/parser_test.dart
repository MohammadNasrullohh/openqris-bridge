import 'package:flutter_test/flutter_test.dart';
import 'package:qris_bridge/core/models/provider_type.dart';
import 'package:qris_bridge/core/parsers/currency_parser.dart';
import 'package:qris_bridge/core/parsers/custom_regex_parser.dart';
import 'package:qris_bridge/core/parsers/notification_parser_registry.dart';

void main() {
  group('CurrencyParser Tests', () {
    test('Parses various Indonesian Rupiah formats correctly', () {
      expect(CurrencyParser.parseRupiah('Rp 25.142'), 25142.0);
      expect(CurrencyParser.parseRupiah('Rp25.142,00'), 25142.0);
      expect(CurrencyParser.parseRupiah('Rp 25.000'), 25000.0);
      expect(CurrencyParser.parseRupiah('25142'), 25142.0);
      expect(CurrencyParser.parseRupiah('IDR 1.250.500'), 1250500.0);
      expect(CurrencyParser.parseRupiah('CR 25.142,00'), 25142.0);
    });

    test('Formats Rupiah correctly', () {
      expect(CurrencyParser.formatRupiah(25142), 'Rp 25.142');
      expect(CurrencyParser.formatRupiah(25000), 'Rp 25.000');
      expect(CurrencyParser.formatRupiah(1500000), 'Rp 1.500.000');
    });
  });

  group('Notification Parser Registry Tests', () {
    final registry = NotificationParserRegistry();

    test('Parses DANA notification correctly', () {
      final mutation = registry.parseNotification(
        packageName: 'id.dana',
        title: 'DANA Bisnis',
        message: 'Berhasil menerima saldo sebesar Rp 25.142 dari BUDI SETIAWAN. Total Saldo kamu sekarang Rp 100.000',
      );

      expect(mutation, isNotNull);
      expect(mutation!.provider, ProviderType.dana);
      expect(mutation.amount, 25142.0);
      expect(mutation.senderName, contains('BUDI SETIAWAN'));
    });

    test('Parses ShopeePay notification correctly', () {
      final mutation = registry.parseNotification(
        packageName: 'com.shopee.id',
        title: 'ShopeePay',
        message: 'Pembayaran QRIS Berhasil! Anda menerima Rp25.142 dari SITI AISYAH',
      );

      expect(mutation, isNotNull);
      expect(mutation!.provider, ProviderType.shopeePay);
      expect(mutation.amount, 25142.0);
      expect(mutation.senderName, contains('SITI AISYAH'));
    });

    test('Parses GoPay / GoBiz notification correctly', () {
      final mutation = registry.parseNotification(
        packageName: 'com.gojek.app',
        title: 'GoPay',
        message: 'Kamu menerima pembayaran GoPay sebesar Rp 25.142 dari AHMAD FAUZI.',
      );

      expect(mutation, isNotNull);
      expect(mutation!.provider, ProviderType.goPay);
      expect(mutation.amount, 25142.0);
      expect(mutation.senderName, contains('AHMAD FAUZI'));
    });

    test('Parses BCA notification correctly', () {
      final mutation = registry.parseNotification(
        packageName: 'com.bca',
        title: 'BCA Mobile',
        message: 'm-Transfer: Rp 25.142 dari REK 012345678 a/n HENDRA KURNIAWAN',
      );

      expect(mutation, isNotNull);
      expect(mutation!.provider, ProviderType.bca);
      expect(mutation.amount, 25142.0);
      expect(mutation.senderName, contains('HENDRA KURNIAWAN'));
    });

    test('Parses Custom Regex Rule', () {
      registry.setCustomRules([
        const CustomRegexRule(
          id: 'rule-bank-jago',
          name: 'Bank Jago',
          packageKeyword: 'jago',
          regexPattern: r'kantong\s+utama\s+kamu\s+menerima\s+Rp\s*([\d\.,]+)\s+dari\s+(.+)',
          amountGroupIndex: 1,
          senderGroupIndex: 2,
        ),
      ]);

      final mutation = registry.parseNotification(
        packageName: 'com.jago.app',
        title: 'Bank Jago',
        message: 'Kantong Utama kamu menerima Rp 25.142 dari DJ STORE',
      );

      expect(mutation, isNotNull);
      expect(mutation!.provider, ProviderType.generic);
      expect(mutation.amount, 25142.0);
      expect(mutation.senderName, 'DJ STORE');
    });
  });
}
