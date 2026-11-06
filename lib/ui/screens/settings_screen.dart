import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/emvco/qris_parser.dart';
import '../../core/manager/unique_code_allocator.dart';
import '../../providers/gateway_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _qrisController;
  late TextEditingController _webhookUrlController;
  late TextEditingController _secretKeyController;
  late TextEditingController _portController;
  late TextEditingController _expiryController;

  late UniqueCodeStrategy _strategy;
  late bool _webhookEnabled;
  late bool _serverEnabled;
  late List<String> _enabledProviders;

  String? _qrisValidationStatus;
  bool _isQrisValid = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<GatewayProvider>().config;
    _qrisController = TextEditingController(text: config.staticQris);
    _webhookUrlController = TextEditingController(text: config.webhookUrl);
    _secretKeyController = TextEditingController(text: config.webhookSecretKey);
    _portController = TextEditingController(text: config.serverPort.toString());
    _expiryController = TextEditingController(text: config.invoiceExpiryMinutes.toString());

    _strategy = config.uniqueCodeStrategy;
    _webhookEnabled = config.webhookEnabled;
    _serverEnabled = config.serverEnabled;
    _enabledProviders = List.from(config.enabledProviders);

    _validateQrisText(config.staticQris);
  }

  @override
  void dispose() {
    _qrisController.dispose();
    _webhookUrlController.dispose();
    _secretKeyController.dispose();
    _portController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  void _validateQrisText(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) {
      setState(() {
        _qrisValidationStatus = null;
        _isQrisValid = false;
      });
      return;
    }

    try {
      final payload = QrisParser.parse(clean);
      if (payload.merchantName != null && payload.merchantName!.isNotEmpty) {
        setState(() {
          _isQrisValid = payload.isValidCrc;
          _qrisValidationStatus = 'MERCHANT: ${payload.merchantName} [${payload.merchantCity ?? "ID"}] • CRC: ${payload.isValidCrc ? "VALID" : "CORRUPT"}';
        });
      } else {
        setState(() {
          _isQrisValid = false;
          _qrisValidationStatus = 'PARSED WITH WARNING: Tag 59 (Merchant Name) absent';
        });
      }
    } catch (_) {
      setState(() {
        _isQrisValid = false;
        _qrisValidationStatus = 'INVALID_EMVCO_PAYLOAD';
      });
    }
  }

  Future<void> _saveAll() async {
    final gateway = context.read<GatewayProvider>();
    final port = int.tryParse(_portController.text.trim()) ?? 8080;
    final expiry = int.tryParse(_expiryController.text.trim()) ?? 15;

    final newConfig = gateway.config.copyWith(
      staticQris: _qrisController.text.trim(),
      uniqueCodeStrategy: _strategy,
      webhookUrl: _webhookUrlController.text.trim(),
      webhookSecretKey: _secretKeyController.text.trim(),
      webhookEnabled: _webhookEnabled,
      serverEnabled: _serverEnabled,
      serverPort: port,
      invoiceExpiryMinutes: expiry,
      enabledProviders: _enabledProviders,
    );

    await gateway.updateConfig(newConfig);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration committed to storage'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testWebhook() async {
    final gateway = context.read<GatewayProvider>();
    if (_webhookUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Specify webhook destination URL first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    gateway.webhookDispatcher.webhookUrl = _webhookUrlController.text.trim();
    gateway.webhookDispatcher.secretKey = _secretKeyController.text.trim();

    final log = await gateway.webhookDispatcher.sendTestPing();

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppTheme.border, width: 1),
          ),
          title: Row(
            children: [
              Icon(
                log.isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                size: 18,
                color: log.isSuccess ? AppTheme.success : AppTheme.danger,
              ),
              const SizedBox(width: 8),
              Text(
                log.isSuccess ? 'WEBHOOK DISPATCH SUCCEEDED' : 'WEBHOOK DISPATCH FAILED',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HTTP STATUS: ${log.statusCode ?? "CONNECTION_FAILED"}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
              Text('ROUND-TRIP LATENCY: ${log.durationMs}ms', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
              if (log.error != null) ...[
                const SizedBox(height: 6),
                Text('ERROR: ${log.error}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.danger)),
              ],
              if (log.responseBody != null) ...[
                const SizedBox(height: 6),
                const Text('RESPONSE PAYLOAD:', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.textMuted)),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.border, width: 1),
                  ),
                  child: Text(
                    log.responseBody!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('DISMISS'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GATEWAY CONFIGURATION'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, size: 18),
            tooltip: 'Commit Changes',
            onPressed: _saveAll,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Static QRIS Base Configuration
            _buildSectionHeader('01 / BASE STATIC QRIS TEMPLATE'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Raw EMVCo string extracted from DANA Bisnis, ShopeePay Merchant, or BCA QRIS:',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _qrisController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: '00020101021126610016ID.CO.SHOPEE.WWW...',
                    ),
                    onChanged: _validateQrisText,
                  ),
                  if (_qrisValidationStatus != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isQrisValid ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                          size: 14,
                          color: _isQrisValid ? AppTheme.success : AppTheme.warning,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _qrisValidationStatus!,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: _isQrisValid ? AppTheme.success : AppTheme.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Unique Code Strategy
            _buildSectionHeader('02 / UNIQUE CODE POLICY & TTL'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ALLOCATION STRATEGY', style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<UniqueCodeStrategy>(
                    value: _strategy,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppTheme.textPrimary),
                    dropdownColor: AppTheme.surfaceElevated,
                    items: UniqueCodeStrategy.values.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s.label.toUpperCase()));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _strategy = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('INVOICE EXPIRATION TTL (MINUTES)', style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: const InputDecoration(hintText: '15'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3. Webhook Integration
            _buildSectionHeader('03 / WEBHOOK DISPATCH CHANNELS'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('DISPATCH WEBHOOKS', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 12)),
                    value: _webhookEnabled,
                    onChanged: (val) => setState(() => _webhookEnabled = val),
                  ),
                  const Text('DESTINATION URL', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _webhookUrlController,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(hintText: 'https://api.yourdomain.com/v1/qris/webhook'),
                  ),
                  const SizedBox(height: 12),
                  const Text('SHARED SECRET (HMAC-SHA256)', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _secretKeyController,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(hintText: 'secret_key_entropy_string'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.send_outlined, size: 14),
                    label: const Text('TEST WEBHOOK PING'),
                    onPressed: _testWebhook,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. Embedded Server Settings
            _buildSectionHeader('04 / EMBEDDED LOCAL HTTP & WS SERVER'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('RUN LOCAL REST/WS SERVER', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 12)),
                    subtitle: const Text('Enables local network clients and POS devices to call API directly on device', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    value: _serverEnabled,
                    onChanged: (val) => setState(() => _serverEnabled = val),
                  ),
                  const SizedBox(height: 6),
                  const Text('BIND PORT', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: const InputDecoration(hintText: '8080'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _saveAll,
              child: const Text('COMMIT SETTINGS'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppTheme.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }
}
