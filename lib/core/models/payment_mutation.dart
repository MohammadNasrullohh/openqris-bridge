import 'provider_type.dart';

/// Represents a parsed incoming financial transaction / mutation.
class PaymentMutation {
  final String id;
  final ProviderType provider;
  final double amount;
  final String? senderName;
  final String? referenceNumber;
  final String rawTitle;
  final String rawMessage;
  final DateTime receivedAt;
  final bool isMatched;
  final String? matchedInvoiceId;

  const PaymentMutation({
    required this.id,
    required this.provider,
    required this.amount,
    this.senderName,
    this.referenceNumber,
    required this.rawTitle,
    required this.rawMessage,
    required this.receivedAt,
    this.isMatched = false,
    this.matchedInvoiceId,
  });

  PaymentMutation copyWith({
    String? id,
    ProviderType? provider,
    double? amount,
    String? senderName,
    String? referenceNumber,
    String? rawTitle,
    String? rawMessage,
    DateTime? receivedAt,
    bool? isMatched,
    String? matchedInvoiceId,
  }) {
    return PaymentMutation(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      amount: amount ?? this.amount,
      senderName: senderName ?? this.senderName,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      rawTitle: rawTitle ?? this.rawTitle,
      rawMessage: rawMessage ?? this.rawMessage,
      receivedAt: receivedAt ?? this.receivedAt,
      isMatched: isMatched ?? this.isMatched,
      matchedInvoiceId: matchedInvoiceId ?? this.matchedInvoiceId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider': provider.displayName,
      'amount': amount,
      'sender_name': senderName,
      'reference_number': referenceNumber,
      'raw_title': rawTitle,
      'raw_message': rawMessage,
      'received_at': receivedAt.toIso8601String(),
      'is_matched': isMatched,
      'matched_invoice_id': matchedInvoiceId,
    };
  }

  factory PaymentMutation.fromJson(Map<String, dynamic> json) {
    return PaymentMutation(
      id: json['id'] as String,
      provider: ProviderType.fromPackageOrName(json['provider'] as String? ?? ''),
      amount: (json['amount'] as num).toDouble(),
      senderName: json['sender_name'] as String?,
      referenceNumber: json['reference_number'] as String?,
      rawTitle: json['raw_title'] as String? ?? '',
      rawMessage: json['raw_message'] as String? ?? '',
      receivedAt: DateTime.parse(json['received_at'] as String),
      isMatched: json['is_matched'] as bool? ?? false,
      matchedInvoiceId: json['matched_invoice_id'] as String?,
    );
  }
}
