/// Utility for cleaning and parsing Indonesian Rupiah amount strings.
class CurrencyParser {
  /// Parses a raw amount string (e.g. "Rp 25.142", "Rp25.142,00", "25,000", "25000", "CR 25.142,00")
  /// into a clean [double].
  static double? parseRupiah(String raw) {
    if (raw.isEmpty) return null;

    // Find the first sequence of numbers, dots, and commas
    final match = RegExp(r'[\d][\d.,]*').firstMatch(raw);
    if (match == null) return null;
    var clean = match.group(0)!.trim();

    if (clean.isEmpty) return null;

    // Check if it has Indonesian comma decimal (e.g. 25.142,00 or 25142,50)
    if (clean.contains(',')) {
      final parts = clean.split(',');
      if (parts.length == 2) {
        // Thousands separator is dot: remove dots from whole part
        final whole = parts[0].replaceAll('.', '');
        final decimal = parts[1];
        clean = '$whole.$decimal';
      } else {
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains('.')) {
      // If it contains dots, determine if dot is thousands separator or decimal:
      // In IDR, amounts rarely have cents. If dot is followed by 3 digits (e.g. 25.000 or 1.250.000), it's thousands separator!
      final lastDotIndex = clean.lastIndexOf('.');
      final charsAfterDot = clean.length - 1 - lastDotIndex;
      if (charsAfterDot == 3) {
        // e.g. 25.000 -> thousands separator
        clean = clean.replaceAll('.', '');
      } else if (charsAfterDot == 2) {
        // e.g. 25000.50 -> decimal
        final whole = clean.substring(0, lastDotIndex).replaceAll('.', '');
        final decimal = clean.substring(lastDotIndex + 1);
        clean = '$whole.$decimal';
      } else {
        // fallback: remove all dots
        clean = clean.replaceAll('.', '');
      }
    }

    return double.tryParse(clean);
  }

  /// Formats amount into standard Indonesian Rupiah display string: "Rp 25.142"
  static String formatRupiah(double amount, {bool includeCents = false}) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final whole = absAmount.truncate();
    final cents = ((absAmount - whole) * 100).round();

    // Group thousands with '.'
    final wholeStr = whole.toString();
    final buffer = StringBuffer();
    final length = wholeStr.length;
    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(wholeStr[i]);
    }

    var result = 'Rp ${buffer.toString()}';
    if (includeCents && cents > 0) {
      result += ',${cents.toString().padLeft(2, '0')}';
    }
    return isNegative ? '-$result' : result;
  }
}
