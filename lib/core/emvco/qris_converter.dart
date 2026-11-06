import 'crc16.dart';
import 'emvco_model.dart';
import 'qris_parser.dart';

/// Converts Indonesian Static QRIS (Dana, ShopeePay, GoPay, BCA, etc.)
/// into Dynamic QRIS with an injected transaction amount and valid CRC16.
class QrisConverter {
  /// Converts a [staticQris] string to a dynamic QRIS string with [amount].
  ///
  /// - [amount]: The exact payment nominal (e.g. 25000 or 25142).
  /// - [invoiceNumber]: Optional invoice or reference code injected into Tag 62 (Additional Data).
  /// - [includeCents]: If true, format amount as `25142.00`, otherwise `25142`.
  static String convertToDynamic({
    required String staticQris,
    required double amount,
    String? invoiceNumber,
    bool includeCents = false,
  }) {
    final clean = staticQris.trim();
    if (clean.isEmpty) {
      throw ArgumentError('Static QRIS string cannot be empty');
    }

    // Parse existing tags
    final tags = QrisParser.parseTlvs(clean);
    if (!tags.containsKey('00')) {
      throw FormatException('Invalid QRIS: missing Tag 00 (Payload Format Indicator)');
    }

    // 1. Point of Initiation Method -> Tag 01 set to '12' (Dynamic)
    tags['01'] = const EmvcoTag(id: '01', length: 2, value: '12');

    // 2. Format Amount -> Tag 54
    final formattedAmount = includeCents
        ? amount.toStringAsFixed(2)
        : amount.toStringAsFixed(0);
    tags['54'] = EmvcoTag(
      id: '54',
      length: formattedAmount.length,
      value: formattedAmount,
    );

    // 3. Ensure Currency is IDR (Tag 53 = '360')
    if (!tags.containsKey('53')) {
      tags['53'] = const EmvcoTag(id: '53', length: 3, value: '360');
    }

    // 4. Ensure Country is ID (Tag 58 = 'ID')
    if (!tags.containsKey('58')) {
      tags['58'] = const EmvcoTag(id: '58', length: 2, value: 'ID');
    }

    // 5. Inject Tag 62 (Additional Data) if invoiceNumber is provided
    if (invoiceNumber != null && invoiceNumber.isNotEmpty) {
      // Build Sub-tag 01 (Bill Number) or Sub-tag 05 (Reference ID)
      final subTag01 = '01${invoiceNumber.length.toString().padLeft(2, '0')}$invoiceNumber';
      tags['62'] = EmvcoTag(
        id: '62',
        length: subTag01.length,
        value: subTag01,
      );
    }

    // 6. Remove existing Tag 63 (CRC) to recompute
    tags.remove('63');

    // 7. Sort and assemble TLV string in standard EMVCo order
    final sortedKeys = tags.keys.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a) ?? 999;
        final bNum = int.tryParse(b) ?? 999;
        return aNum.compareTo(bNum);
      });

    final buffer = StringBuffer();
    for (final key in sortedKeys) {
      buffer.write(tags[key]!.toTlvString());
    }

    // 8. Append Tag 63 with length 04
    buffer.write('6304');

    // 9. Compute CRC16-CCITT
    final assembledBeforeCrc = buffer.toString();
    final crc = Crc16Ccitt.computeHex(assembledBeforeCrc);

    return '$assembledBeforeCrc$crc';
  }

  /// Verifies if a given string is a valid QRIS payload and matches the expected amount.
  static bool verifyDynamicQris(String qris, double expectedAmount) {
    if (!Crc16Ccitt.isValidQrisCrc(qris)) return false;
    final payload = QrisParser.parse(qris);
    if (!payload.isDynamic) return false;
    if (payload.transactionAmount == null) return false;
    return (payload.transactionAmount! - expectedAmount).abs() < 0.01;
  }
}
