import 'package:uuid/uuid.dart';
import '../models/payment_mutation.dart';
import 'bca_parser.dart';
import 'brimo_parser.dart';
import 'custom_regex_parser.dart';
import 'dana_parser.dart';
import 'gopay_parser.dart';
import 'mandiri_parser.dart';
import 'ovo_parser.dart';
import 'seabank_parser.dart';
import 'shopee_parser.dart';
import 'base_notification_parser.dart';

/// Central registry that manages and executes all notification parsers.
class NotificationParserRegistry {
  static final NotificationParserRegistry _instance =
      NotificationParserRegistry._internal();
  factory NotificationParserRegistry() => _instance;

  final List<BaseNotificationParser> _parsers = [];
  CustomNotificationParser _customParser = CustomNotificationParser();
  static const _uuid = Uuid();

  NotificationParserRegistry._internal() {
    _registerDefaultParsers();
  }

  void _registerDefaultParsers() {
    _parsers.addAll([
      DanaNotificationParser(),
      ShopeeNotificationParser(),
      GoPayNotificationParser(),
      OvoNotificationParser(),
      BcaNotificationParser(),
      MandiriNotificationParser(),
      BrimoNotificationParser(),
      SeaBankNotificationParser(),
    ]);
  }

  /// Sets custom regex rules
  void setCustomRules(List<CustomRegexRule> rules) {
    _customParser = CustomNotificationParser(rules: rules);
  }

  /// Attempts to parse a notification from any supported e-wallet or bank.
  PaymentMutation? parseNotification({
    required String packageName,
    required String title,
    required String message,
    DateTime? timestamp,
    String? id,
  }) {
    final effectiveTime = timestamp ?? DateTime.now();
    final effectiveId = id ?? _uuid.v4();

    // 1. Try standard built-in parsers
    for (final parser in _parsers) {
      if (parser.canHandle(packageName, title, message)) {
        final mutation = parser.parse(
          id: effectiveId,
          packageName: packageName,
          title: title,
          message: message,
          timestamp: effectiveTime,
        );
        if (mutation != null) {
          return mutation;
        }
      }
    }

    // 2. Try custom regex parser
    if (_customParser.canHandle(packageName, title, message)) {
      final customMutation = _customParser.parse(
        id: effectiveId,
        packageName: packageName,
        title: title,
        message: message,
        timestamp: effectiveTime,
      );
      if (customMutation != null) {
        return customMutation;
      }
    }

    // 3. Fallback: try all parsers even if canHandle didn't match package (e.g. if SMS or generic title)
    for (final parser in _parsers) {
      final fallbackMutation = parser.parse(
        id: effectiveId,
        packageName: packageName,
        title: title,
        message: message,
        timestamp: effectiveTime,
      );
      if (fallbackMutation != null) {
        return fallbackMutation;
      }
    }

    return null;
  }
}
