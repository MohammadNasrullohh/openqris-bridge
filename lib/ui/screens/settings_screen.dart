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
      setState(() => _qrisValidationStatus = null);
      return;
    }

    try {
      final payload = QrisParser.parse(clean);
      if (payload.merchantName != null && payload.merchantName!.isNotEmpty) {
        setState(() {
          _qrisValidationStatus = 'Valid: ${payload.merchantName} (${payload.merchantCity ?? "ID"}) • CRC: ${payload.isValidCrc ? "OK" : "Perlu Koreksi"}';
        });
      } else {
        setState(() => _qrisValidationStatus = 'Format QRIS terdeteksi tapi nama toko tidak ditemukan.');
      }
    } catch (_) {
      setState(() => _qrisValidationStatus = 'Bukan string EMVCo QRIS yang valid.');
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
          content: Text('Pengaturan berhasil disimpan'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    }
  }

  Future<void> _testWebhook() async {
    final gateway = context.read<GatewayProvider>();
    if (_webhookUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan URL webhook terlebih dahulu')),
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
          backgroundColor: AppTheme.surfaceDark,
          title: Text(log.isSuccess ? '✅ Webhook Berhasil' : '❌ Webhook Gagal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status Code: ${log.statusCode ?? "N/A"}'),
              Text('Latency: ${log.durationMs} ms'),
              if (log.error != null) Text('Error: ${log.error}', style: const TextStyle(color: Colors.red)),
              if (log.responseBody != null) Text('Response: ${log.responseBody}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
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
        title: const Text('Pengaturan Gateway'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Simpan',
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
            _buildSectionHeader('1. QRIS Statis Toko (DANA / Shopee / BCA / Bank)'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Salin teks/string QRIS statis dari aplikasi DANA Bisnis, ShopeePay Merchant, atau QRIS cetak Anda:',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _qrisController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: '00020101021126610016ID.CO.SHOPEE.WWW...',
                    ),
                    onChanged: _validateQrisText,
                  ),
                  if (_qrisValidationStatus != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _qrisValidationStatus!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _qrisValidationStatus!.startsWith('Valid')
                            ? AppTheme.primaryColor
                            : Colors.amber,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Unique Code Strategy
            _buildSectionHeader('2. Pengaturan Kode Unik & Kadaluarsa'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Strategi Kode Unik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UniqueCodeStrategy>(
                    value: _strategy,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                    dropdownColor: AppTheme.surfaceDark,
                    items: UniqueCodeStrategy.values.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s.label));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _strategy = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Waktu Kadaluarsa Transaksi (Menit)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '15'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Webhook Integration
            _buildSectionHeader('3. Webhook Notifikasi ke Server Toko'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktifkan Webhook', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    value: _webhookEnabled,
                    onChanged: (val) => setState(() => _webhookEnabled = val),
                  ),
                  const Text('URL Endpoint Webhook Merchant:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _webhookUrlController,
                    decoration: const InputDecoration(hintText: 'https://tokosaya.com/api/payment/webhook'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Secret Key (HMAC-SHA256):', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _secretKeyController,
                    decoration: const InputDecoration(hintText: 'secret_key_anda_123'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Kirim Test Ping Webhook'),
                    onPressed: _testWebhook,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Embedded Server Settings
            _buildSectionHeader('4. Embedded Server HP (REST API & WebSocket)'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Jalankan Local Server di HP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Website / POS di jaringan yang sama bisa langsung panggil API HP ini', style: TextStyle(fontSize: 11)),
                    value: _serverEnabled,
                    onChanged: (val) => setState(() => _serverEnabled = val),
                  ),
                  const SizedBox(height: 8),
                  const Text('Port Server:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: '8080'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Simpan Seluruh Pengaturan', style: TextStyle(fontSize: 16)),
              onPressed: _saveAll,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppTheme.secondaryColor,
      ),
    );
  }
}
