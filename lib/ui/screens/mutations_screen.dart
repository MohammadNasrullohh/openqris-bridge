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
        title: const Text('Log Mutasi & Notifikasi'),
        actions: [
          IconButton(
            tooltip: 'Status Listener',
            icon: Icon(
              gateway.isListenerPermissionGranted ? Icons.notifications_active : Icons.notifications_off,
              color: gateway.isListenerPermissionGranted ? AppTheme.primaryColor : Colors.amber,
            ),
            onPressed: () => gateway.requestPermission(),
          ),
        ],
      ),
      body: mutations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mark_email_read_outlined, size: 48, color: Colors.grey.shade600),
                  const SizedBox(height: 12),
                  const Text(
                    'Belum ada mutasi masuk',
                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Notifikasi dari DANA, ShopeePay, GoPay, BCA dll akan muncul otomatis di sini.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
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
    final timeStr = DateFormat('HH:mm:ss • dd MMM yyyy').format(mut.receivedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: mut.isMatched
                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                : Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            mut.isMatched ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
            color: mut.isMatched ? AppTheme.primaryColor : Colors.amber,
          ),
        ),
        title: Row(
          children: [
            Text(
              CurrencyParser.formatRupiah(mut.amount),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.darkBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF475569)),
              ),
              child: Text(
                mut.provider.displayName,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${mut.senderName ?? "Pengirim Tidak Terdeteksi"} • $timeStr',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: mut.isMatched ? const Color(0xFF064E3B) : const Color(0xFF451A03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            mut.isMatched ? 'MATCHED' : 'UNMATCHED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: mut.isMatched ? const Color(0xFF34D399) : Colors.amber,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mut.matchedInvoiceId != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.link, size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Cocok dengan: ${mut.matchedInvoiceId}',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Judul Notifikasi:',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  mut.rawTitle.isNotEmpty ? mut.rawTitle : '-',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Isi Pesan Notifikasi:',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    mut.rawMessage,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
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
