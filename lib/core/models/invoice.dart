enum InvoiceStatus {
  pending('PENDING'),
  paid('PAID'),
  expired('EXPIRED'),
  cancelled('CANCELLED');

  final String value;
  const InvoiceStatus(this.value);

  static InvoiceStatus fromString(String val) {
    for (final s in InvoiceStatus.values) {
      if (s.value.equalsIgnoreCase(val) || s.name.equalsIgnoreCase(val)) {
        return s;
      }
    }
    return InvoiceStatus.pending;
  }
}

extension _CaseInsensitiveCompare on String {
  bool equalsIgnoreCase(String other) => toLowerCase() == other.toLowerCase();
}

/// Represents an invoice generated for a merchant order.
class Invoice {
  final String id;
  final String? referenceId;
  final double baseAmount;
  final int uniqueCode;
  final double totalAmount;
  final String qrisRaw;
  final InvoiceStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? paidAt;
  final String? matchedMutationId;
  final Map<String, dynamic> metadata;

  const Invoice({
    required this.id,
    this.referenceId,
    required this.baseAmount,
    required this.uniqueCode,
    required this.totalAmount,
    required this.qrisRaw,
    this.status = InvoiceStatus.pending,
    required this.createdAt,
    required this.expiresAt,
    this.paidAt,
    this.matchedMutationId,
    this.metadata = const {},
  });

  bool get isPending => status == InvoiceStatus.pending;
  bool get isPaid => status == InvoiceStatus.paid;
  bool get isExpired => status == InvoiceStatus.expired;
  bool get isCancelled => status == InvoiceStatus.cancelled;

  /// Time remaining before expiration in seconds
  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  Invoice copyWith({
    String? id,
    String? referenceId,
    double? baseAmount,
    int? uniqueCode,
    double? totalAmount,
    String? qrisRaw,
    InvoiceStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? paidAt,
    String? matchedMutationId,
    Map<String, dynamic>? metadata,
  }) {
    return Invoice(
      id: id ?? this.id,
      referenceId: referenceId ?? this.referenceId,
      baseAmount: baseAmount ?? this.baseAmount,
      uniqueCode: uniqueCode ?? this.uniqueCode,
      totalAmount: totalAmount ?? this.totalAmount,
      qrisRaw: qrisRaw ?? this.qrisRaw,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      paidAt: paidAt ?? this.paidAt,
      matchedMutationId: matchedMutationId ?? this.matchedMutationId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference_id': referenceId,
      'base_amount': baseAmount,
      'unique_code': uniqueCode,
      'total_amount': totalAmount,
      'qris_raw': qrisRaw,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'matched_mutation_id': matchedMutationId,
      'metadata': metadata,
    };
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String,
      referenceId: json['reference_id'] as String?,
      baseAmount: (json['base_amount'] as num).toDouble(),
      uniqueCode: (json['unique_code'] as num).toInt(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      qrisRaw: json['qris_raw'] as String,
      status: InvoiceStatus.fromString(json['status'] as String? ?? 'PENDING'),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
      matchedMutationId: json['matched_mutation_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }
}
