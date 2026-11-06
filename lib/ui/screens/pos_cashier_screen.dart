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

  final List<double> _presetAmounts = [10000, 25000, 50000, 75000, 100000, 150000];

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
        const SnackBar(content: Text('Masukkan nominal pembayaran yang valid (misal: 25.000)')),
      );
      return;
    }

    final gateway = context.read<GatewayProvider>();

    if (gateway.config.staticQris.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Atur string QRIS Statis dasar di menu Pengaturan terlebih dahulu!'),
          backgroundColor: Colors.amber,
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

    // Update _currentInvoice state if it changed in provider (e.g. marked PAID!)
    if (_currentInvoice != null) {
      final updated = gateway.invoiceManager.getInvoice(_currentInvoice!.id);
      if (updated != null && updated.status != _currentInvoice!.status) {
        _currentInvoice = updated;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir QRIS Cepat'),
        actions: [
          if (_currentInvoice != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reset Kasir',
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
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nominal Pembayaran',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
            decoration: const InputDecoration(
              prefixText: 'Rp ',
              prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
              hintText: '25.000',
              hintStyle: TextStyle(fontSize: 32, color: Colors.white24),
            ),
          ),
          const SizedBox(height: 16),
          // Quick amount chip buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetAmounts.map((amt) {
              return ActionChip(
                backgroundColor: AppTheme.surfaceDark,
                side: const BorderSide(color: Color(0xFF334155)),
                label: Text(
                  CurrencyParser.formatRupiah(amt),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  _amountController.text = amt.toInt().toString();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            'Catatan / Nomor Meja / Order ID (Opsional)',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _refController,
            decoration: const InputDecoration(
              hintText: 'Contoh: MEJA-07 atau INV-99',
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.qr_code_2_rounded, size: 24),
            label: const Text('Tampilkan QRIS Dinamis', style: TextStyle(fontSize: 18)),
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
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isPaid) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF064E3B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor, size: 40),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PEMBAYARAN DITERIMA!',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Mutasi berhasil dicocokkan otomatis & Webhook terkirim.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // QR Code Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: isPaid
                ? const SizedBox(
                    width: 240,
                    height: 240,
                    child: Center(
                      child: Icon(Icons.verified_rounded, size: 100, color: AppTheme.primaryColor),
                    ),
                  )
                : QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
          ),
          const SizedBox(height: 20),

          // Total Amount
          Text(
            CurrencyParser.formatRupiah(inv.totalAmount),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryColor,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Nominal: ${CurrencyParser.formatRupiah(inv.baseAmount)}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              if (inv.uniqueCode != 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Kode Unik: ${inv.uniqueCode > 0 ? "+${inv.uniqueCode}" : inv.uniqueCode}',
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          StatusPill(status: inv.status),
          const SizedBox(height: 8),
          Text(
            'Invoice: ${inv.id} ${inv.referenceId != null ? "• ${inv.referenceId}" : ""}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 24),

          if (!isPaid) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondaryColor),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Menunggu transfer dari DANA / Shopee / BCA / E-Wallet...',
                    style: TextStyle(color: AppTheme.secondaryColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaid ? AppTheme.primaryColor : AppTheme.surfaceDark,
                    foregroundColor: isPaid ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: Text(isPaid ? 'Transaksi Baru' : 'Selesai / Transaksi Baru'),
                  onPressed: _resetCashier,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
