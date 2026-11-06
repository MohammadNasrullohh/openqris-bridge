import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/invoice.dart';
import '../../core/parsers/currency_parser.dart';
import '../../providers/gateway_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/qr_dialog.dart';
import '../widgets/status_pill.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final gateway = context.watch<GatewayProvider>();
    final invoices = gateway.invoiceManager.allInvoices;
    final paidInvoices = invoices.where((i) => i.isPaid).toList();
    final pendingInvoices = invoices.where((i) => i.isPending).toList();

    final totalRevenue = paidInvoices.fold<double>(
      0.0,
      (sum, i) => sum + i.totalAmount,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenQris Bridge'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan Gateway',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => onNavigate(4), // Navigate to Settings
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await gateway.checkPermission();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // System Status Banner
              _buildStatusBanner(context, gateway),
              const SizedBox(height: 16),

              // Metric Cards Row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Total Pendapatan',
                      value: CurrencyParser.formatRupiah(totalRevenue),
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Transaksi Sukses',
                      value: '${paidInvoices.length} Lunas',
                      icon: Icons.check_circle_outline_rounded,
                      color: Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Menunggu Bayar',
                      value: '${pendingInvoices.length} Pending',
                      icon: Icons.hourglass_top_rounded,
                      color: Colors.amberAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Fast Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.point_of_sale_rounded),
                      label: const Text('Kasir QRIS'),
                      onPressed: () => onNavigate(1), // POS
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('Simulator Test'),
                      onPressed: () => onNavigate(3), // Simulator
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section: Active Pending Invoices
              if (pendingInvoices.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Menunggu Pembayaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => onNavigate(2), // Invoices Tab
                      child: const Text('Lihat Semua'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...pendingInvoices.take(3).map((inv) => _buildInvoiceCard(context, inv)),
                const SizedBox(height: 16),
              ],

              // Section: Recent Invoices
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Transaksi Terakhir',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onNavigate(2),
                    child: const Text('Lihat Semua'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (invoices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade600),
                        const SizedBox(height: 12),
                        const Text(
                          'Belum ada transaksi',
                          style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tekan "Kasir QRIS" untuk membuat QR transaksi pertama',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...invoices.take(5).map((inv) => _buildInvoiceCard(context, inv)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, GatewayProvider gateway) {
    final hasPermission = gateway.isListenerPermissionGranted;
    final serverRunning = gateway.isServerRunning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPermission ? const Color(0xFF065F46) : const Color(0xFF991B1B),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasPermission ? Icons.radio_button_checked : Icons.warning_amber_rounded,
                color: hasPermission ? AppTheme.primaryColor : Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasPermission
                      ? 'Listener Notifikasi Aktif'
                      : 'Izin Akses Notifikasi Diperlukan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: hasPermission ? Colors.white : Colors.amber,
                    fontSize: 14,
                  ),
                ),
              ),
              if (!hasPermission && gateway.nativeBridgeService.isAndroidSupported)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: Colors.amber,
                  ),
                  onPressed: () => gateway.requestPermission(),
                  child: const Text('Aktifkan', style: TextStyle(fontSize: 12, color: Colors.black)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasPermission
                ? 'Aplikasi siap mendengarkan mutasi otomatis dari DANA, ShopeePay, GoPay, OVO, BCA, Livin, BRImo.'
                : 'Diperlukan untuk membaca pop-up notifikasi pembayaran masuk dari aplikasi e-wallet.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const Divider(height: 20, color: Color(0xFF334155)),
          Row(
            children: [
              Icon(
                serverRunning ? Icons.dns_rounded : Icons.dns_outlined,
                size: 16,
                color: serverRunning ? AppTheme.secondaryColor : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                serverRunning
                    ? 'Server REST & WS: Port ${gateway.activeServerPort ?? 8080} (Siap Terima API)'
                    : 'Server REST: Nonaktif',
                style: TextStyle(
                  fontSize: 12,
                  color: serverRunning ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(BuildContext context, Invoice inv) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => QrDialog.show(context, inv),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.darkBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          CurrencyParser.formatRupiah(inv.totalAmount),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (inv.uniqueCode != 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(+${inv.uniqueCode})',
                            style: const TextStyle(color: Colors.amber, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${inv.id} • ${inv.referenceId ?? "Tanpa Ref"}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              StatusPill(status: inv.status),
            ],
          ),
        ),
      ),
    );
  }
}
