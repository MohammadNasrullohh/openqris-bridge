import '../models/payment_mutation.dart';
import '../models/provider_type.dart';
import 'base_notification_parser.dart';
import 'currency_parser.dart';

/// Parser for GoPay / GoBiz notifications (com.gojek.app, com.gobiz).
/// Handles:
/// - "Kamu menerima pembayaran GoPay sebesar Rp 25.142 dari AHMAD"
/// - "Hore! Pembayaran QRIS sebesar Rp 25.142 berhasil diterima."
/// - "GoPay masuk! Rp 25.142 dari BUDI"
class GoPayNotificationParser extends BaseNotificationParser {
  @override
  ProviderType get provider => ProviderType.goPay;

  static final List<RegExp> _patterns = [
    // 1. Kamu menerima pembayaran GoPay sebesar Rp 25.142 dari (SENDER)
    RegExp(
      r'(?:pembayaran\s+gopay\s+sebesar|menerima\s+pembayaran\s+gopay.*?sebesar|gopay\s+masuk!?)\s+(?:Rp\.?\s*)?([\d.,]+)(?:\s+dari\s+([^\.]+))?',
      caseSensitive: false,
    ),
    // 2. Pembayaran QRIS sebesar Rp 25.142 berhasil diterima
    RegExp(
      r'pembayaran\s+qris\s+sebesar\s+(?:Rp\.?\s*)?([\d.,]+)',
      caseSensitive: false,
    ),
    // 3. Saldo GoPay kamu bertambah Rp 25.142
    RegExp(
      r'saldo\s+gopay.*?bertambah\s+(?:Rp\.?\s*)?([\d.,]+)',
      caseSensitive: false,
    ),
  ];

  @override
  bool canHandle(String packageName, String title, String message) {
    final lowerPkg = packageName.toLowerCase();
    final lowerTitle = title.toLowerCase();
    final lowerMsg = message.toLowerCase();

    return lowerPkg.contains('gojek') ||
        lowerPkg.contains('gobiz') ||
        lowerTitle.contains('gopay') ||
        lowerTitle.contains('gobiz') ||
        lowerMsg.contains('gopay');
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
