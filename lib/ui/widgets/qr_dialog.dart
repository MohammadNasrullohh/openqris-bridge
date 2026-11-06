import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/invoice.dart';
import '../../core/parsers/currency_parser.dart';
import '../theme/app_theme.dart';
import 'status_pill.dart';

class QrDialog extends StatelessWidget {
  final Invoice invoice;

  const QrDialog({super.key, required this.invoice});

  static void show(BuildContext context, Invoice invoice) {
    showDialog(
      context: context,
      builder: (ctx) => QrDialog(invoice: invoice),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrData = invoice.qrisRaw.isNotEmpty
        ? invoice.qrisRaw
        : 'EMPTY_QRIS_STRING_PLEASE_SET_BASE_QRIS_IN_SETTINGS';

    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    invoice.id,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  StatusPill(status: invoice.status),
                ],
              ),
              const SizedBox(height: 16),
              // QR Code Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              // Amount breakdown
              Text(
                CurrencyParser.formatRupiah(invoice.totalAmount),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Nominal: ${CurrencyParser.formatRupiah(invoice.baseAmount)}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  if (invoice.uniqueCode != 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Kode Unik: ${invoice.uniqueCode > 0 ? '+${invoice.uniqueCode}' : invoice.uniqueCode}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.darkBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Bayar dengan DANA, ShopeePay, GoPay, BCA dll.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Salin String QRIS'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: invoice.qrisRaw));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('String QRIS berhasil disalin')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
