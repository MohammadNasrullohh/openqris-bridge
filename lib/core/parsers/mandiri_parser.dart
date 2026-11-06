import '../models/payment_mutation.dart';
import '../models/provider_type.dart';
import 'base_notification_parser.dart';
import 'currency_parser.dart';

/// Parser for Livin' by Mandiri (id.co.bankmandiri.livin).
class MandiriNotificationParser extends BaseNotificationParser {
  @override
  ProviderType get provider => ProviderType.mandiri;

  static final List<RegExp> _patterns = [
    // 1. Transfer Masuk Rp 25.142 dari SENDER
    RegExp(
      r'(?:transfer\s+masuk|dana\s+masuk)\s+(?:sebesar\s+)?(?:Rp\.?\s*)?([\d.,]+)(?:\s+dari\s+([^\.]+))?',
      caseSensitive: false,
    ),
    // 2. QR Pembayaran berhasil diterima sebesar Rp 25.142
    RegExp(
      r'(?:pembayaran\s+qr|qris)\s+berhasil.*?(?:sebesar\s+)?(?:Rp\.?\s*)?([\d.,]+)',
      caseSensitive: false,
    ),
  ];

  @override
  bool canHandle(String packageName, String title, String message) {
    final lowerPkg = packageName.toLowerCase();
    final lowerTitle = title.toLowerCase();
    final lowerMsg = message.toLowerCase();

    return lowerPkg.contains('bankmandiri') ||
        lowerPkg.contains('livin') ||
        lowerTitle.contains('livin') ||
        lowerTitle.contains('mandiri') ||
        lowerMsg.contains('livin');
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
