import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
        title: const Text('TRANSACTION LEDGER'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.textPrimary,
          indicatorWeight: 2,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          tabs: [
            Tab(text: 'ALL [${filtered.length}]'),
            Tab(text: 'PENDING [${pending.length}]'),
            Tab(text: 'SETTLED [${paid.length}]'),
            Tab(text: 'CLOSED [${expired.length}]'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Filter by ID, reference, or amount...',
                prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
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
          children: const [
            Icon(Icons.inbox_outlined, size: 28, color: AppTheme.textMuted),
            SizedBox(height: 8),
            Text(
              'No matching transactions',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: list.length,
      itemBuilder: (ctx, index) {
        final inv = list[index];
        final timeStr = DateFormat('yyyy-MM-dd HH:mm').format(inv.createdAt);

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
                        const SizedBox(height: 3),
                        Text(
                          '${inv.id} • $timeStr',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: AppTheme.textMuted,
                          ),
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
                          'TTL: ${inv.remainingSeconds}s',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.textMuted),
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
