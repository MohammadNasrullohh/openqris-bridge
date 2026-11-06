import 'crc16.dart';
import 'emvco_model.dart';

/// Parses raw QRIS EMVCo string into structured tags and validate data.
class QrisParser {
  /// Parses TLVs from any EMVCo formatted string.
  static Map<String, EmvcoTag> parseTlvs(String raw) {
    final Map<String, EmvcoTag> tags = {};
    int index = 0;

    while (index + 4 <= raw.length) {
      final tagId = raw.substring(index, index + 2);
      final tagNum = int.tryParse(tagId);
      if (tagNum == null) {
        // Tag IDs must be numeric 00..99
        break;
      }

      final lengthStr = raw.substring(index + 2, index + 4);
      final length = int.tryParse(lengthStr);

      if (length == null || length < 0) {
        break;
      }

      final valueStart = index + 4;
      final valueEnd = valueStart + length;

      if (valueEnd > raw.length) {
        // Truncated payload or invalid length
        break;
      }

      final value = raw.substring(valueStart, valueEnd);

      // Check if tag is nested (e.g. tag 26-51 or 62)
      Map<String, EmvcoTag>? subTags;
      if ((tagNum >= 26 && tagNum <= 51) || tagId == '62') {
        try {
          final parsedSubs = parseTlvs(value);
          if (parsedSubs.isNotEmpty) {
            subTags = parsedSubs;
          }
        } catch (_) {
          // If sub-tag parsing fails, keep subTags null and retain raw value
        }
      }

      tags[tagId] = EmvcoTag(
        id: tagId,
        length: length,
        value: value,
        subTags: subTags,
      );

      index = valueEnd;
    }

    return tags;
  }

  /// Parses an entire QRIS string into a [QrisPayload] with validation.
  static QrisPayload parse(String rawQris) {
    final clean = rawQris.trim();
    final isValidCrc = Crc16Ccitt.isValidQrisCrc(clean);
    final tags = parseTlvs(clean);

    return QrisPayload(
      raw: clean,
      tags: tags,
      isValidCrc: isValidCrc,
    );
  }
}
