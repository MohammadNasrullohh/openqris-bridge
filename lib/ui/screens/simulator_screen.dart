import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/provider_type.dart';
import '../../core/parsers/currency_parser.dart';
import '../../providers/gateway_provider.dart';
import '../theme/app_theme.dart';

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  ProviderType _selectedProvider = ProviderType.dana;
  final TextEditingController _amountController = TextEditingController(text: '25142');
  final TextEditingController _senderController = TextEditingController(text: 'BUDI SETIAWAN');
  Map<String, dynamic>? _lastSimulationResult;

  @override
  void dispose() {
    _amountController.dispose();
    _senderController.dispose();
    super.dispose();
  }

  String _generateNotificationMessage(ProviderType provider, double amount, String sender) {
    final amtFormatted = CurrencyParser.formatRupiah(amount);
    switch (provider) {
      case ProviderType.dana:
        return 'Berhasil menerima saldo sebesar $amtFormatted dari $sender. Total Saldo DANA kamu sekarang Rp 500.000';
      case ProviderType.shopeePay:
        return 'Pembayaran QRIS Berhasil! Anda menerima $amtFormatted dari $sender';
      case ProviderType.goPay:
        return 'Kamu menerima pembayaran GoPay sebesar $amtFormatted dari $sender.';
      case ProviderType.bca:
        return 'm-Transfer: $amtFormatted dari REK 012345678 a/n $sender';
      case ProviderType.mandiri:
        return 'Transfer Masuk $amtFormatted dari $sender ke rekening Mandiri.';
      case ProviderType.bri:
        return 'Transfer masuk $amtFormatted dari $sender.';
      case ProviderType.ovo:
        return 'Transaksi berhasil! Kamu telah menerima OVO Cash sebesar $amtFormatted dari $sender.';
      case ProviderType.seabank:
        return 'Transfer Masuk $amtFormatted dari $sender.';
      case ProviderType.generic:
        return 'Pembayaran masuk sebesar $amtFormatted dari $sender';
    }
  }

  void _runSimulation() {
    final amount = CurrencyParser.parseRupiah(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal valid')),
      );
      return;
    }

    final sender = _senderController.text.trim().isNotEmpty
        ? _senderController.text.trim()
        : 'TEST USER';

    final message = _generateNotificationMessage(_selectedProvider, amount, sender);
    final title = _selectedProvider.displayName;

    final gateway = context.read<GatewayProvider>();
    final matchedInvoice = gateway.simulateIncomingNotification(
      packageName: _selectedProvider.packageName,
      title: title,
      message: message,
    );

    setState(() {
      _lastSimulationResult = {
        'provider': _selectedProvider.displayName,
        'amount': amount,
        'sender': sender,
        'message': message,
        'matched': matchedInvoice != null,
        'invoice_id': matchedInvoice?.id,
        'timestamp': DateTime.now(),
      };
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          matchedInvoice != null
              ? '✅ Berhasil dicocokkan dengan ${matchedInvoice.id}!'
              : '⚠️ Notifikasi diproses tapi tidak ada invoice pending yang cocok dengan nominal ini.',
        ),
        backgroundColor: matchedInvoice != null ? AppTheme.primaryColor : Colors.amber.shade800,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gateway = context.watch<GatewayProvider>();
    final pendingInvoices = gateway.invoiceManager.pendingInvoices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulator Notifikasi & Webhook'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    'Pilih Aplikasi Pembayaran (E-Wallet / Bank)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ProviderType>(
                    value: _selectedProvider,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                    dropdownColor: AppTheme.surfaceDark,
                    items: ProviderType.values.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text('${p.displayName} (${p.description})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedProvider = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  if (pendingInvoices.isNotEmpty) ...[
                    const Text(
                      'Pilih Nominal dari Transaksi Pending:',
                      style: TextStyle(fontSize: 12, color: AppTheme.secondaryColor, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: pendingInvoices.take(3).map((inv) {
                        return ActionChip(
                          backgroundColor: AppTheme.darkBg,
                          label: Text(
                            '${CurrencyParser.formatRupiah(inv.totalAmount)} (${inv.id})',
                            style: const TextStyle(fontSize: 11, color: Colors.amber),
                          ),
                          onPressed: () {
                            _amountController.text = inv.totalAmount.toInt().toString();
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const Text(
                    'Nominal Transfer / Mutasi Masuk (Rupiah)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    decoration: const InputDecoration(
                      prefixText: 'Rp ',
                      hintText: '25.142',
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Nama Pengirim / Customer',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _senderController,
                    decoration: const InputDecoration(
                      hintText: 'Nama di rekening pengirim',
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('Simulasikan Notifikasi Masuk'),
                    onPressed: _runSimulation,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_lastSimulationResult != null) ...[
              const Text(
                'Hasil Pengujian Terakhir:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _lastSimulationResult!['matched'] == true
                        ? AppTheme.primaryColor
                        : Colors.amber,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _lastSimulationResult!['matched'] == true
                              ? Icons.check_circle_rounded
                              : Icons.info_outline,
                          color: _lastSimulationResult!['matched'] == true
                              ? AppTheme.primaryColor
                              : Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _lastSimulationResult!['matched'] == true
                              ? 'MATCHED (INVOICE DILUNASI & WEBHOOK DISPATCHED)'
                              : 'MUTASI TERCATAT (UNMATCHED)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _lastSimulationResult!['matched'] == true
                                ? AppTheme.primaryColor
                                : Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFF334155)),
                    Text(
                      'Pesan yang Ditiru:',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastSimulationResult!['message'] as String,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                    if (_lastSimulationResult!['invoice_id'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Invoice Dilunasi: ${_lastSimulationResult!['invoice_id']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
