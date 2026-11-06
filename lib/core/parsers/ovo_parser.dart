import '../models/payment_mutation.dart';
import '../models/provider_type.dart';
import 'base_notification_parser.dart';
import 'currency_parser.dart';

/// Parser for OVO notifications (ovo.id).
class OvoNotificationParser extends BaseNotificationParser {
  @override
  ProviderType get provider => ProviderType.ovo;

  static final List<RegExp> _patterns = [
    // 1. Berhasil! Kamu telah menerima OVO Cash sebesar Rp 25.142 dari (SENDER)
    RegExp(
      r'(?:menerima\s+ovo\s+cash\s+sebesar|telah\s+menerima)\s+(?:Rp\.?\s*)?([\d.,]+)(?:\s+dari\s+([^\.]+))?',
      caseSensitive: false,
    ),
    // 2. Top up berhasil! Saldo OVO Cash kamu bertambah Rp 25.142
    RegExp(
      r'bertambah\s+(?:Rp\.?\s*)?([\d.,]+)',
      caseSensitive: false,
    ),
    // 3. Transaksi QRIS ... Rp 25.142
    RegExp(
      r'(?:transaksi|qris).*?(?:sebesar\s+)?(?:Rp\.?\s*)?([\d.,]+)\s+berhasil',
      caseSensitive: false,
    ),
  ];

  @override
  bool canHandle(String packageName, String title, String message) {
    final lowerPkg = packageName.toLowerCase();
    final lowerTitle = title.toLowerCase();
    final lowerMsg = message.toLowerCase();

    return lowerPkg.contains('ovo') ||
        lowerTitle.contains('ovo') ||
        lowerMsg.contains('ovo');
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
