import '../models/payment_mutation.dart';
import '../models/provider_type.dart';
import 'base_notification_parser.dart';
import 'currency_parser.dart';

/// User-configured custom regex rule.
class CustomRegexRule {
  final String id;
  final String name;
  final String packageKeyword;
  final String regexPattern;
  final int amountGroupIndex;
  final int? senderGroupIndex;
  final bool isEnabled;

  const CustomRegexRule({
    required this.id,
    required this.name,
    required this.packageKeyword,
    required this.regexPattern,
    this.amountGroupIndex = 1,
    this.senderGroupIndex,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'package_keyword': packageKeyword,
      'regex_pattern': regexPattern,
      'amount_group_index': amountGroupIndex,
      'sender_group_index': senderGroupIndex,
      'is_enabled': isEnabled,
    };
  }

  factory CustomRegexRule.fromJson(Map<String, dynamic> json) {
    return CustomRegexRule(
      id: json['id'] as String,
      name: json['name'] as String,
      packageKeyword: json['package_keyword'] as String,
      regexPattern: json['regex_pattern'] as String,
      amountGroupIndex: (json['amount_group_index'] as num?)?.toInt() ?? 1,
      senderGroupIndex: (json['sender_group_index'] as num?)?.toInt(),
      isEnabled: json['is_enabled'] as bool? ?? true,
    );
  }
}

/// Dynamic parser that executes user-defined custom regex rules.
class CustomNotificationParser extends BaseNotificationParser {
  final List<CustomRegexRule> rules;

  CustomNotificationParser({this.rules = const []});

  @override
  ProviderType get provider => ProviderType.generic;

  @override
  bool canHandle(String packageName, String title, String message) {
    final lowerPkg = packageName.toLowerCase();
    for (final rule in rules) {
      if (!rule.isEnabled) continue;
      if (rule.packageKeyword.isEmpty || lowerPkg.contains(rule.packageKeyword.toLowerCase())) {
        return true;
      }
    }
    return false;
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
    final lowerPkg = packageName.toLowerCase();

    for (final rule in rules) {
      if (!rule.isEnabled) continue;
      if (rule.packageKeyword.isNotEmpty && !lowerPkg.contains(rule.packageKeyword.toLowerCase())) {
        continue;
      }

      try {
        final reg = RegExp(rule.regexPattern, caseSensitive: false);
        final match = reg.firstMatch(combined);
        if (match != null) {
          final rawAmount = match.group(rule.amountGroupIndex);
          if (rawAmount == null) continue;

          final amount = CurrencyParser.parseRupiah(rawAmount);
          if (amount != null && amount > 0) {
            String? sender;
            if (rule.senderGroupIndex != null && rule.senderGroupIndex! <= match.groupCount) {
              sender = match.group(rule.senderGroupIndex!)?.trim();
            }

            return PaymentMutation(
              id: id,
              provider: ProviderType.generic,
              amount: amount,
              senderName: sender,
              rawTitle: title,
              rawMessage: message,
              receivedAt: timestamp,
            );
          }
        }
      } catch (_) {
        // Invalid regex ignore
      }
    }

    return null;
  }
}
