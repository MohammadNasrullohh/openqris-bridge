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
        const SnackBar(
          content: Text('Enter a valid nominal'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final sender = _senderController.text.trim().isNotEmpty
        ? _senderController.text.trim()
        : 'TEST_USER';

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
              ? 'Matched with ${matchedInvoice.id} • Webhook dispatched'
              : 'Mutation parsed • No active invoice matched this exact nominal',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gateway = context.watch<GatewayProvider>();
    final pendingInvoices = gateway.invoiceManager.pendingInvoices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('INGESTION TEST BENCH'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    'SOURCE EMULATOR',
                    style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 10, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<ProviderType>(
                    value: _selectedProvider,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppTheme.textPrimary),
                    dropdownColor: AppTheme.surfaceElevated,
                    items: ProviderType.values.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text('${p.displayName.toUpperCase()} (${p.packageName})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedProvider = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  if (pendingInvoices.isNotEmpty) ...[
                    const Text(
                      'ACTIVE PENDING QUEUE (CLICK TO SYNC NOMINAL):',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.info, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: pendingInvoices.take(3).map((inv) {
                        return ActionChip(
                          backgroundColor: AppTheme.surfaceElevated,
                          side: const BorderSide(color: AppTheme.border, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          label: Text(
                            '${CurrencyParser.formatRupiah(inv.totalAmount)} [${inv.id}]',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.warning),
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
                    'TRANSFER AMOUNT (IDR)',
                    style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 10, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      prefixText: 'IDR ',
                      hintText: '25142',
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'SENDER ACCOUNT NAME',
                    style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 10, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _senderController,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'e.g. AHMAD FAUZI',
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('DISPATCH SIMULATED NOTIFICATION'),
                    onPressed: _runSimulation,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_lastSimulationResult != null) ...[
              const Text(
                'EXECUTION TRACE',
                style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _lastSimulationResult!['matched'] == true
                        ? AppTheme.success.withValues(alpha: 0.5)
                        : AppTheme.warning.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _lastSimulationResult!['matched'] == true
                              ? Icons.check_circle_outline
                              : Icons.help_outline,
                          size: 14,
                          color: _lastSimulationResult!['matched'] == true
                              ? AppTheme.success
                              : AppTheme.warning,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _lastSimulationResult!['matched'] == true
                              ? 'MATCHED -> INVOICE RECONCILED -> WEBHOOK DISPATCHED'
                              : 'MUTASI LOGGED -> UNMATCHED (NO PENDING INVOICE)',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            color: _lastSimulationResult!['matched'] == true
                              ? AppTheme.success
                              : AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    const Text(
                      'INTERCEPTED NOTIFICATION PAYLOAD:',
                      style: TextStyle(fontFamily: 'monospace', color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.border, width: 1),
                      ),
                      child: Text(
                        _lastSimulationResult!['message'] as String,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textSecondary),
                      ),
                    ),
                    if (_lastSimulationResult!['invoice_id'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'SETTLED INVOICE: ${_lastSimulationResult!['invoice_id']}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success,
                        ),
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
