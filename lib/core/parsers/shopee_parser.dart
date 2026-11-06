import '../models/payment_mutation.dart';
import '../models/provider_type.dart';
import 'base_notification_parser.dart';
import 'currency_parser.dart';

/// Parser for Shopee / ShopeePay / Shopee Merchant notifications.
/// Handles:
/// - "Pembayaran QRIS Berhasil! Anda menerima Rp25.142 dari ..."
/// - "Kamu telah menerima dana sebesar Rp25.142 dari ShopeePay..."
/// - "Transfer berhasil! Rp25.142 telah masuk ke ShopeePay-mu."
/// - "QRIS Received: Rp 25.142 from..."
class ShopeeNotificationParser extends BaseNotificationParser {
  @override
  ProviderType get provider => ProviderType.shopeePay;

  static final List<RegExp> _patterns = [
    // 1. Pembayaran QRIS Berhasil! Anda menerima Rp25.142 dari BUDI
    RegExp(
      r'(?:anda\s+menerima|menerima\s+dana\s+sebesar|kamu\s+telah\s+menerima)\s+(?:Rp\.?\s*)?([\d.,]+)(?:\s+dari\s+([^\.]+))?',
      caseSensitive: false,
    ),
    // 2. Pembayaran QRIS ... Rp 25.142
    RegExp(
      r'(?:pembayaran\s+qris|qris\s+received).*?(?:Rp\.?\s*)?([\d.,]+)',
      caseSensitive: false,
    ),
    // 3. Transfer berhasil! Rp25.142 telah masuk
    RegExp(
      r'(?:Rp\.?\s*)?([\d.,]+)\s+telah\s+masuk\s+ke\s+shopeepay',
      caseSensitive: false,
    ),
    // 4. Saldo ShopeePay bertambah Rp25.142
    RegExp(
      r'shopeepay\s+bertambah\s+(?:sebesar\s+)?(?:Rp\.?\s*)?([\d.,]+)',
      caseSensitive: false,
    ),
  ];

  @override
  bool canHandle(String packageName, String title, String message) {
    final lowerPkg = packageName.toLowerCase();
    final lowerTitle = title.toLowerCase();
    final lowerMsg = message.toLowerCase();

    return lowerPkg.contains('shopee') ||
        lowerTitle.contains('shopee') ||
        lowerMsg.contains('shopeepay') ||
        lowerMsg.contains('shopee');
  }

  @override
  PaymentMutation? parse({
    required String id,
    required String packageName,
    required String title,
    required String message,
    required DateTime timestamp,
  }) {
    final combined = '$title $message';

    for (final regex in _patterns) {
      final match = regex.firstMatch(combined);
      if (match != null) {
        final rawAmount = match.group(1);
        if (rawAmount == null) continue;

        final amount = CurrencyParser.parseRupiah(rawAmount);
        if (amount != null && amount > 0) {
          String? sender;
          if (match.groupCount >= 2) {
            sender = match.group(2)?.trim();
          }

          return PaymentMutation(
            id: id,
            provider: provider,
            amount: amount,
            senderName: sender,
            rawTitle: title,
            rawMessage: message,
            receivedAt: timestamp,
          );
        }
      }
    }

    return null;
  }
}
