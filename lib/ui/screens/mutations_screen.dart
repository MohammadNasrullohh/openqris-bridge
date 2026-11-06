import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/payment_mutation.dart';
import '../../core/parsers/currency_parser.dart';
import '../../providers/gateway_provider.dart';
import '../theme/app_theme.dart';

class MutationsScreen extends StatelessWidget {
  const MutationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gateway = context.watch<GatewayProvider>();
    final mutations = gateway.invoiceManager.allMutations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MUTATION INGESTION LOG'),
        actions: [
          IconButton(
            tooltip: 'Listener Status',
            icon: Icon(
              Icons.circle,
              size: 10,
              color: gateway.isListenerPermissionGranted ? AppTheme.success : AppTheme.danger,
            ),
            onPressed: () => gateway.requestPermission(),
          ),
        ],
      ),
      body: mutations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.terminal_outlined, size: 28, color: AppTheme.textMuted),
                  SizedBox(height: 8),
                  Text(
                    'No incoming mutation events logged',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: mutations.length,
              itemBuilder: (ctx, index) {
                final mut = mutations[index];
                return _buildMutationCard(context, gateway, mut);
              },
            ),
    );
  }

  Widget _buildMutationCard(
    BuildContext context,
    GatewayProvider gateway,
    PaymentMutation mut,
  ) {
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(mut.receivedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Icon(
          mut.isMatched ? Icons.check_circle_outline : Icons.help_outline,
          size: 18,
          color: mut.isMatched ? AppTheme.success : AppTheme.warning,
        ),
        title: Row(
          children: [
            Text(
              CurrencyParser.formatRupiah(mut.amount),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: AppTheme.border, width: 1),
              ),
              child: Text(
                mut.provider.displayName.toUpperCase(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${mut.senderName ?? "UNKNOWN_SENDER"} • $timeStr',
          style: const TextStyle(fontFamily: 'monospace', color: AppTheme.textMuted, fontSize: 10),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: (mut.isMatched ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: (mut.isMatched ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.3)),
          ),
          child: Text(
            mut.isMatched ? 'RECONCILED' : 'UNMATCHED',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: mut.isMatched ? AppTheme.success : AppTheme.warning,
            ),
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
              color: AppTheme.surfaceElevated,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mut.matchedInvoiceId != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.link, size: 12, color: AppTheme.success),
                      const SizedBox(width: 6),
                      Text(
                        'LINKED INVOICE: ${mut.matchedInvoiceId}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: AppTheme.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'NOTIFICATION TITLE:',
                  style: TextStyle(fontFamily: 'monospace', color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700),
                ),
                Text(
                  mut.rawTitle.isNotEmpty ? mut.rawTitle : '-',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'RAW PAYLOAD:',
                  style: TextStyle(fontFamily: 'monospace', color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.border, width: 1),
                  ),
                  child: Text(
                    mut.rawMessage,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
