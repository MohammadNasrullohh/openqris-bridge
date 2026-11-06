import '../models/payment_mutation.dart';
import '../models/provider_type.dart';

/// Base contract for provider-specific notification parsers.
abstract class BaseNotificationParser {
  ProviderType get provider;

  /// Returns true if this parser can handle the notification
  bool canHandle(String packageName, String title, String message);

  /// Attempts to parse amount, sender, and reference from notification
  PaymentMutation? parse({
    required String id,
    required String packageName,
    required String title,
    required String message,
    required DateTime timestamp,
  });
}
