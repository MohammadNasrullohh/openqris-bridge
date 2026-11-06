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
        title: const Row(
          children: [
            Icon(Icons.hub_outlined, size: 18, color: AppTheme.textPrimary),
            SizedBox(width: 8),
            Text('OPENQRIS BRIDGE'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune_outlined, size: 18),
            onPressed: () => onNavigate(5),
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
              // System Topology Status Box
              _buildSystemStatus(context, gateway),
              const SizedBox(height: 14),

              // KPI Row
              Row(
                children: [
                  Expanded(
                    child: _buildKpiBox(
                      label: 'SETTLED VOLUME',
                      value: CurrencyParser.formatRupiah(totalRevenue),
                      subtext: '${paidInvoices.length} transactions',
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildKpiBox(
                      label: 'PENDING ESCROW',
                      value: '${pendingInvoices.length}',
                      subtext: 'Awaiting webhook',
                      color: AppTheme.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quick Action Toolbar
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Invoice / POS'),
                      onPressed: () => onNavigate(1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.terminal_outlined, size: 16),
                      label: const Text('Test Bench'),
                      onPressed: () => onNavigate(3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Active Pending Queue
              if (pendingInvoices.isNotEmpty) ...[
                _buildSectionHeader('ACTIVE PENDING INVOICES (${pendingInvoices.length})'),
                const SizedBox(height: 8),
                ...pendingInvoices.take(3).map((inv) => _buildInvoiceItem(context, inv)),
                const SizedBox(height: 16),
              ],

              // Recent Transaction Log
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('TRANSACTION LEDGER'),
                  InkWell(
                    onTap: () => onNavigate(2),
                    child: const Text(
                      'VIEW ALL',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (invoices.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.border, width: 1),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined, size: 28, color: AppTheme.textMuted),
                        SizedBox(height: 8),
                        Text(
                          'No transactions recorded',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...invoices.take(6).map((inv) => _buildInvoiceItem(context, inv)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatus(BuildContext context, GatewayProvider gateway) {
    final hasPerm = gateway.isListenerPermissionGranted;
    final serverOn = gateway.isServerRunning;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasPerm ? AppTheme.success : AppTheme.danger,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasPerm ? 'NOTIFICATION LISTENER: ACTIVE' : 'NOTIFICATION LISTENER: ACCESS REQUIRED',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: hasPerm ? AppTheme.textPrimary : AppTheme.warning,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (!hasPerm && gateway.nativeBridgeService.isAndroidSupported)
                SizedBox(
                  height: 28,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
                    onPressed: () => gateway.requestPermission(),
                    child: const Text('Grant Access', style: TextStyle(fontSize: 11)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: serverOn ? AppTheme.info : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    serverOn
                        ? 'EMBEDDED SERVER: PORT ${gateway.activeServerPort ?? 8080}'
                        : 'EMBEDDED SERVER: OFF',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    gateway.config.webhookEnabled ? 'HMAC-SHA256' : 'WEBHOOK OFF',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBox({
    required String label,
    required String value,
    required String subtext,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textMuted,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildInvoiceItem(BuildContext context, Invoice inv) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => QrDialog.show(context, inv),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          CurrencyParser.formatRupiah(inv.totalAmount),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (inv.uniqueCode != 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '[${inv.uniqueCode > 0 ? "+${inv.uniqueCode}" : inv.uniqueCode}]',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: AppTheme.warning,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${inv.id}${inv.referenceId != null ? " • ${inv.referenceId}" : ""}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
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
