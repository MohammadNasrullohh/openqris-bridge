import '../models/payment_mutation.dart';
import '../models/provider_type.dart';
import 'base_notification_parser.dart';
import 'currency_parser.dart';

/// Parser for DANA notifications (id.dana).
/// Handles:
/// - "Berhasil menerima saldo sebesar Rp 25.142 dari BUDI SETIAWAN..."
/// - "Kamu menerima Rp 25.142 dari AHMAD..."
/// - "Pembayaran QRIS Rp25.142 berhasil diterima."
/// - "Top up Rp 25.142 dari BCA..."
class DanaNotificationParser extends BaseNotificationParser {
  @override
  ProviderType get provider => ProviderType.dana;

  static final List<RegExp> _patterns = [
    // 1. Berhasil menerima saldo sebesar Rp 25.142 dari (SENDER)
    RegExp(
      r'(?:berhasil\s+menerima\s+saldo\s+sebesar|menerima\s+saldo\s+sebesar|kamu\s+menerima)\s+(?:Rp\.?\s*)?([\d.,]+)(?:\s+dari\s+([^\.]+))?',
      caseSensitive: false,
    ),
    // 2. Pembayaran QRIS Rp25.142 berhasil
    RegExp(
      r'pembayaran\s+qris\s+(?:sebesar\s+)?(?:Rp\.?\s*)?([\d.,]+)(?:\s+berhasil|\s+diterima)?',
      caseSensitive: false,
    ),
    // 3. Top up Rp 25.142 dari (BANK)
    RegExp(
      r'top\s*up\s+(?:sebesar\s+)?(?:Rp\.?\s*)?([\d.,]+)(?:\s+dari\s+([^\.]+))?',
      caseSensitive: false,
    ),
    // 4. Saldo bertambah Rp 25.142
    RegExp(
      r'saldo\s+bertambah\s+(?:Rp\.?\s*)?([\d.,]+)',
      caseSensitive: false,
    ),
  ];

  @override
  bool canHandle(String packageName, String title, String message) {
    final lowerPkg = packageName.toLowerCase();
    final lowerTitle = title.toLowerCase();
    final lowerMsg = message.toLowerCase();

    return lowerPkg.contains('id.dana') ||
        lowerTitle.contains('dana') ||
        (lowerMsg.contains('dana') && lowerMsg.contains('saldo'));
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
