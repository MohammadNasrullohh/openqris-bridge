import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/invoice.dart';
import '../../core/parsers/currency_parser.dart';
import '../../providers/gateway_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/status_pill.dart';

class PosCashierScreen extends StatefulWidget {
  const PosCashierScreen({super.key});

  @override
  State<PosCashierScreen> createState() => _PosCashierScreenState();
}

class _PosCashierScreenState extends State<PosCashierScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _refController = TextEditingController();
  Invoice? _currentInvoice;

  final List<double> _presetAmounts = [10000, 25000, 50000, 75000, 100000, 250000];

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    super.dispose();
  }

  void _generateQr() {
    final rawText = _amountController.text.trim();
    final amount = CurrencyParser.parseRupiah(rawText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid transaction nominal (e.g. 25000)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final gateway = context.read<GatewayProvider>();

    if (gateway.config.staticQris.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Warning: Static QRIS base string is empty. Set it in Settings.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final inv = gateway.createInvoice(
      baseAmount: amount,
      referenceId: _refController.text.trim().isNotEmpty ? _refController.text.trim() : null,
    );

    setState(() {
      _currentInvoice = inv;
    });
  }

  void _resetCashier() {
    setState(() {
      _currentInvoice = null;
      _amountController.clear();
      _refController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gateway = context.watch<GatewayProvider>();

    if (_currentInvoice != null) {
      final updated = gateway.invoiceManager.getInvoice(_currentInvoice!.id);
      if (updated != null && updated.status != _currentInvoice!.status) {
        _currentInvoice = updated;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('POINT OF SALE / CASHIER'),
        actions: [
          if (_currentInvoice != null)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'New Transaction',
              onPressed: _resetCashier,
            ),
        ],
      ),
      body: _currentInvoice == null
          ? _buildInputForm()
          : _buildActiveInvoiceView(_currentInvoice!),
    );
  }

  Widget _buildInputForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'BASE NOMINAL',
            style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            decoration: const InputDecoration(
              prefixText: 'IDR ',
              prefixStyle: TextStyle(fontFamily: 'monospace', fontSize: 24, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              hintText: '25000',
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _presetAmounts.map((amt) {
              return ActionChip(
                backgroundColor: AppTheme.surfaceElevated,
                side: const BorderSide(color: AppTheme.border, width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                label: Text(
                  CurrencyParser.formatRupiah(amt),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  _amountController.text = amt.toInt().toString();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          const Text(
            'REFERENCE ID / NOTE (OPTIONAL)',
            style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _refController,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'e.g. ORDER-1029 or TABLE-04',
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.qr_code_2, size: 18),
            label: const Text('GENERATE DYNAMIC QRIS'),
            onPressed: _generateQr,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveInvoiceView(Invoice inv) {
    final isPaid = inv.isPaid;
    final qrData = inv.qrisRaw.isNotEmpty ? inv.qrisRaw : 'SAMPLE_QRIS_STRING';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPaid) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.4), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PAYMENT CONFIRMED (PAID)',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: AppTheme.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Mutation reconciled • Webhook dispatched: ${inv.id}',
                          style: const TextStyle(fontFamily: 'monospace', color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // QR Card
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: isPaid
                  ? const SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(
                        child: Icon(Icons.verified, size: 72, color: AppTheme.success),
                      ),
                    )
                  : QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: Column(
              children: [
                Text(
                  CurrencyParser.formatRupiah(inv.totalAmount),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Base: ${CurrencyParser.formatRupiah(inv.baseAmount)} • Unique Code: ${inv.uniqueCode >= 0 ? "+${inv.uniqueCode}" : inv.uniqueCode}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 8),
                StatusPill(status: inv.status),
                const SizedBox(height: 6),
                Text(
                  'ID: ${inv.id}${inv.referenceId != null ? " • REF: ${inv.referenceId}" : ""}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!isPaid) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.info),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Listening for incoming payment notification...',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          OutlinedButton.icon(
            icon: const Icon(Icons.arrow_back, size: 14),
            label: Text(isPaid ? 'NEW TRANSACTION' : 'CANCEL / NEW TRANSACTION'),
            onPressed: _resetCashier,
          ),
        ],
      ),
    );
  }
}
