import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/manager/unique_code_allocator.dart';
import '../core/parsers/custom_regex_parser.dart';

class GatewayConfig {
  final String staticQris;
  final UniqueCodeStrategy uniqueCodeStrategy;
  final int minUniqueCode;
  final int maxUniqueCode;
  final int invoiceExpiryMinutes;
  final String webhookUrl;
  final String webhookSecretKey;
  final bool webhookEnabled;
  final bool serverEnabled;
  final int serverPort;
  final List<String> enabledProviders;
  final List<CustomRegexRule> customRules;

  const GatewayConfig({
    this.staticQris = '',
    this.uniqueCodeStrategy = UniqueCodeStrategy.random,
    this.minUniqueCode = 1,
    this.maxUniqueCode = 999,
    this.invoiceExpiryMinutes = 15,
    this.webhookUrl = '',
    this.webhookSecretKey = '',
    this.webhookEnabled = true,
    this.serverEnabled = true,
    this.serverPort = 8080,
    this.enabledProviders = const [
      'DANA',
      'ShopeePay',
      'GoPay',
      'OVO',
      'BCA',
      'Mandiri',
      'BRI',
      'SeaBank',
    ],
    this.customRules = const [],
  });

  GatewayConfig copyWith({
    String? staticQris,
    UniqueCodeStrategy? uniqueCodeStrategy,
    int? minUniqueCode,
    int? maxUniqueCode,
    int? invoiceExpiryMinutes,
    String? webhookUrl,
    String? webhookSecretKey,
    bool? webhookEnabled,
    bool? serverEnabled,
    int? serverPort,
    List<String>? enabledProviders,
    List<CustomRegexRule>? customRules,
  }) {
    return GatewayConfig(
      staticQris: staticQris ?? this.staticQris,
      uniqueCodeStrategy: uniqueCodeStrategy ?? this.uniqueCodeStrategy,
      minUniqueCode: minUniqueCode ?? this.minUniqueCode,
      maxUniqueCode: maxUniqueCode ?? this.maxUniqueCode,
      invoiceExpiryMinutes: invoiceExpiryMinutes ?? this.invoiceExpiryMinutes,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      webhookSecretKey: webhookSecretKey ?? this.webhookSecretKey,
      webhookEnabled: webhookEnabled ?? this.webhookEnabled,
      serverEnabled: serverEnabled ?? this.serverEnabled,
      serverPort: serverPort ?? this.serverPort,
      enabledProviders: enabledProviders ?? this.enabledProviders,
      customRules: customRules ?? this.customRules,
    );
  }
}

class StorageService {
  static const _keyStaticQris = 'config_static_qris';
  static const _keyUniqueStrategy = 'config_unique_strategy';
  static const _keyMinUnique = 'config_min_unique';
  static const _keyMaxUnique = 'config_max_unique';
  static const _keyExpiryMinutes = 'config_expiry_minutes';
  static const _keyWebhookUrl = 'config_webhook_url';
  static const _keyWebhookSecret = 'config_webhook_secret';
  static const _keyWebhookEnabled = 'config_webhook_enabled';
  static const _keyServerEnabled = 'config_server_enabled';
  static const _keyServerPort = 'config_server_port';
  static const _keyEnabledProviders = 'config_enabled_providers';
  static const _keyCustomRules = 'config_custom_rules';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  GatewayConfig loadConfig() {
    final strategyStr = _prefs.getString(_keyUniqueStrategy);
    UniqueCodeStrategy strategy = UniqueCodeStrategy.random;
    if (strategyStr != null) {
      for (final s in UniqueCodeStrategy.values) {
        if (s.name == strategyStr) {
          strategy = s;
          break;
        }
      }
    }

    final customRulesJson = _prefs.getString(_keyCustomRules);
    List<CustomRegexRule> rules = [];
    if (customRulesJson != null && customRulesJson.isNotEmpty) {
      try {
        final list = jsonDecode(customRulesJson) as List;
        rules = list.map((e) => CustomRegexRule.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    return GatewayConfig(
      staticQris: _prefs.getString(_keyStaticQris) ?? '',
      uniqueCodeStrategy: strategy,
      minUniqueCode: _prefs.getInt(_keyMinUnique) ?? 1,
      maxUniqueCode: _prefs.getInt(_keyMaxUnique) ?? 999,
      invoiceExpiryMinutes: _prefs.getInt(_keyExpiryMinutes) ?? 15,
      webhookUrl: _prefs.getString(_keyWebhookUrl) ?? '',
      webhookSecretKey: _prefs.getString(_keyWebhookSecret) ?? 'secret_qris_bridge_${DateTime.now().year}',
      webhookEnabled: _prefs.getBool(_keyWebhookEnabled) ?? true,
      serverEnabled: _prefs.getBool(_keyServerEnabled) ?? true,
      serverPort: _prefs.getInt(_keyServerPort) ?? 8080,
      enabledProviders: _prefs.getStringList(_keyEnabledProviders) ?? [
        'DANA',
        'ShopeePay',
        'GoPay',
        'OVO',
        'BCA',
        'Mandiri',
        'BRI',
        'SeaBank',
      ],
      customRules: rules,
    );
  }

  Future<void> saveConfig(GatewayConfig config) async {
    await _prefs.setString(_keyStaticQris, config.staticQris);
    await _prefs.setString(_keyUniqueStrategy, config.uniqueCodeStrategy.name);
    await _prefs.setInt(_keyMinUnique, config.minUniqueCode);
    await _prefs.setInt(_keyMaxUnique, config.maxUniqueCode);
    await _prefs.setInt(_keyExpiryMinutes, config.invoiceExpiryMinutes);
    await _prefs.setString(_keyWebhookUrl, config.webhookUrl);
    await _prefs.setString(_keyWebhookSecret, config.webhookSecretKey);
    await _prefs.setBool(_keyWebhookEnabled, config.webhookEnabled);
    await _prefs.setBool(_keyServerEnabled, config.serverEnabled);
    await _prefs.setInt(_keyServerPort, config.serverPort);
    await _prefs.setStringList(_keyEnabledProviders, config.enabledProviders);
    final rulesJson = jsonEncode(config.customRules.map((r) => r.toJson()).toList());
    await _prefs.setString(_keyCustomRules, rulesJson);
  }
}
