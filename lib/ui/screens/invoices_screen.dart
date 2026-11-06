import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/invoice.dart';
import '../../core/parsers/currency_parser.dart';
import '../../providers/gateway_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/qr_dialog.dart';
import '../widgets/status_pill.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gateway = context.watch<GatewayProvider>();
    final allInvoices = gateway.invoiceManager.allInvoices;

    final filtered = allInvoices.where((inv) {
      if (_searchQuery.isEmpty) return true;
      final matchesId = inv.id.toLowerCase().contains(_searchQuery);
      final matchesRef = inv.referenceId?.toLowerCase().contains(_searchQuery) ?? false;
      final matchesAmt = inv.totalAmount.toString().contains(_searchQuery);
      return matchesId || matchesRef || matchesAmt;
    }).toList();

    final pending = filtered.where((i) => i.isPending).toList();
    final paid = filtered.where((i) => i.isPaid).toList();
    final expired = filtered.where((i) => i.isExpired || i.isCancelled).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Transaksi'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(text: 'Semua (${filtered.length})'),
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'Lunas (${paid.length})'),
            Tab(text: 'Selesai (${expired.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari invoice ID, nominal, atau catatan...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInvoiceList(context, gateway, filtered),
                _buildInvoiceList(context, gateway, pending),
                _buildInvoiceList(context, gateway, paid),
                _buildInvoiceList(context, gateway, expired),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(
    BuildContext context,
    GatewayProvider gateway,
    List<Invoice> list,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 12),
            const Text('Tidak ada transaksi', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: list.length,
      itemBuilder: (ctx, index) {
        final inv = list[index];
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
                          '${inv.id} ${inv.referenceId != null ? "• ${inv.referenceId}" : ""}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusPill(status: inv.status),
                      if (inv.isPending) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Sisa ${inv.remainingSeconds}d',
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
