import '../models/payment_mutation.dart';
import '../models/provider_type.dart';
import 'base_notification_parser.dart';
import 'currency_parser.dart';

/// Parser for BCA Mobile, myBCA, and BCA SMS notifications.
/// Handles:
/// - "QRIS Diterima Rp 25.142 dari BUDI..."
/// - "m-Transfer: Rp 25.142 dari REK 123456789 a/n AGUS..."
/// - "06/11 CR 25.142,00 12345/TRSF/AHMAD"
class BcaNotificationParser extends BaseNotificationParser {
  @override
  ProviderType get provider => ProviderType.bca;

  static final List<RegExp> _patterns = [
    // 1. QRIS Diterima Rp 25.142 dari BUDI
    RegExp(
      r'qris\s+diterima\s+(?:Rp\.?\s*)?([\d.,]+)(?:\s+dari\s+([^\.]+))?',
      caseSensitive: false,
    ),
    // 2. m-Transfer: Rp 25.142 dari REK ... a/n SENDER
    RegExp(
      r'm-transfer:\s*(?:Rp\.?\s*)?([\d.,]+)(?:\s+dari.*?(?:a/n|an)\s+([^\.]+))?',
      caseSensitive: false,
    ),
    // 3. SMS Banking BCA: CR 25.142,00 (Credit = Masuk)
    RegExp(
      r'\bCR\s+([\d.,]+)(?:.*?TRSF/(.+))?',
      caseSensitive: false,
    ),
    // 4. Transfer Masuk: Rp 25.142
    RegExp(
      r'(?:transfer|dana)\s+masuk\s+(?:sebesar\s+)?(?:Rp\.?\s*)?([\d.,]+)(?:\s+dari\s+([^\.]+))?',
      caseSensitive: false,
    ),
  ];

  @override
  bool canHandle(String packageName, String title, String message) {
    final lowerPkg = packageName.toLowerCase();
    final lowerTitle = title.toLowerCase();
    final lowerMsg = message.toLowerCase();

    return lowerPkg.contains('com.bca') ||
        lowerTitle.contains('bca') ||
        lowerMsg.contains('bca') ||
        lowerMsg.contains('m-transfer');
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
