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
    final qrData = invoice.qrisRaw.isNotEmpty ? invoice.qrisRaw : 'NO_QRIS_CONFIGURED';

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.border, width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    invoice.id,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  StatusPill(status: invoice.status),
                ],
              ),
              const SizedBox(height: 16),

              // QR Code container
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 210,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Nominal Display
              Center(
                child: Column(
                  children: [
                    Text(
                      CurrencyParser.formatRupiah(invoice.totalAmount),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Base: ${CurrencyParser.formatRupiah(invoice.baseAmount)} • Code: ${invoice.uniqueCode >= 0 ? "+${invoice.uniqueCode}" : invoice.uniqueCode}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.border, width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'DANA, ShopeePay, GoPay, BCA, Mandiri, BRI, SeaBank',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Copy QR String'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: invoice.qrisRaw));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('QRIS string copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
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
