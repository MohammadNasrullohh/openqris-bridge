/// Implementation of CRC-16/CCITT-FALSE according to EMVCo / Bank Indonesia QRIS Specification.
/// - Polynomial: 0x1021
/// - Initial value: 0xFFFF
/// - RefIn: false
/// - RefOut: false
/// - XorOut: 0x0000
class Crc16Ccitt {
  static const int _polynomial = 0x1021;
  static const int _initialValue = 0xFFFF;

  /// Calculates CRC-16/CCITT-FALSE integer for the given [data].
  static int compute(String data) {
    int crc = _initialValue;
    final bytes = data.codeUnits;

    for (final byte in bytes) {
      crc ^= (byte << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ _polynomial) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }

    return crc & 0xFFFF;
  }

  /// Calculates CRC-16/CCITT-FALSE and returns a 4-character uppercase Hex string (e.g. 'ABCD').
  static String computeHex(String data) {
    final crc = compute(data);
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Validates if an EMVCo QRIS string has a valid CRC16 tag (Tag 63).
  static bool isValidQrisCrc(String qrisString) {
    if (qrisString.length < 8) return false;
    final lastTagIndex = qrisString.lastIndexOf('6304');
    if (lastTagIndex == -1 || lastTagIndex != qrisString.length - 8) {
      return false;
    }

    final dataToVerify = qrisString.substring(0, lastTagIndex + 4);
    final expectedCrc = qrisString.substring(lastTagIndex + 4).toUpperCase();
    final calculatedCrc = computeHex(dataToVerify);

    return expectedCrc == calculatedCrc;
  }
}
