/// Represents an EMVCo Tag-Length-Value (TLV) element.
class EmvcoTag {
  final String id;
  final int length;
  final String value;
  final Map<String, EmvcoTag>? subTags;

  const EmvcoTag({
    required this.id,
    required this.length,
    required this.value,
    this.subTags,
  });

  /// Formats the tag back into EMVCo TLV string: ID(2) + LEN(2) + VALUE
  String toTlvString() {
    final lenStr = length.toString().padLeft(2, '0');
    return '$id$lenStr$value';
  }

  @override
  String toString() => 'Tag($id, len: $length, val: $value)';
}

/// Parsed QRIS Payload with convenient getters for Indonesian QRIS fields.
class QrisPayload {
  final String raw;
  final Map<String, EmvcoTag> tags;
  final bool isValidCrc;

  const QrisPayload({
    required this.raw,
    required this.tags,
    required this.isValidCrc,
  });

  /// Tag 00: Payload Format Indicator (standard is '01')
  String? get payloadFormatIndicator => tags['00']?.value;

  /// Tag 01: Point of Initiation Method ('11' for static, '12' for dynamic)
  String? get pointOfInitiationMethod => tags['01']?.value;

  /// Whether this QRIS is static (customer types amount)
  bool get isStatic => pointOfInitiationMethod == '11';

  /// Whether this QRIS is dynamic (pre-filled amount)
  bool get isDynamic => pointOfInitiationMethod == '12';

  /// Tag 52: Merchant Category Code (MCC)
  String? get merchantCategoryCode => tags['52']?.value;

  /// Tag 53: Transaction Currency (standard IDR is '360')
  String? get transactionCurrency => tags['53']?.value;

  /// Tag 54: Transaction Amount (if dynamic)
  double? get transactionAmount {
    final val = tags['54']?.value;
    if (val == null || val.isEmpty) return null;
    return double.tryParse(val);
  }

  /// Tag 58: Country Code (standard Indonesia is 'ID')
  String? get countryCode => tags['58']?.value;

  /// Tag 59: Merchant Name
  String? get merchantName => tags['59']?.value;

  /// Tag 60: Merchant City
  String? get merchantCity => tags['60']?.value;

  /// Tag 61: Postal Code
  String? get postalCode => tags['61']?.value;

  /// Tag 62: Additional Data Template
  EmvcoTag? get additionalData => tags['62'];

  /// Tag 63: CRC16 value
  String? get crc => tags['63']?.value;
}
