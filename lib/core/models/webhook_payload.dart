import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'invoice.dart';
import 'payment_mutation.dart';

/// Formats and signs webhook payloads sent to merchant backends.
class WebhookPayload {
  final String event;
  final DateTime timestamp;
  final Invoice invoice;
  final PaymentMutation? mutation;

  const WebhookPayload({
    required this.event,
    required this.timestamp,
    required this.invoice,
    this.mutation,
  });

  Map<String, dynamic> toMap() {
    return {
      'event': event,
      'timestamp': timestamp.toIso8601String(),
      'invoice': invoice.toJson(),
      'mutation': mutation?.toJson(),
    };
  }

  String toJsonString() => jsonEncode(toMap());

  /// Computes HMAC-SHA256 signature using the merchant's secret key.
  String computeSignature(String secretKey) {
    final keyBytes = utf8.encode(secretKey);
    final dataBytes = utf8.encode(toJsonString());
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(dataBytes);
    return digest.toString();
  }

  /// Verifies incoming HMAC-SHA256 signature
  static bool verifySignature({
    required String payloadJson,
    required String secretKey,
    required String expectedSignature,
  }) {
    final keyBytes = utf8.encode(secretKey);
    final dataBytes = utf8.encode(payloadJson);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(dataBytes);
    return digest.toString().toLowerCase() == expectedSignature.toLowerCase();
  }
}
