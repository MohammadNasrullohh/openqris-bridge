import 'package:flutter/material.dart';
import '../../core/models/invoice.dart';
import '../theme/app_theme.dart';

class StatusPill extends StatelessWidget {
  final InvoiceStatus status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case InvoiceStatus.paid:
        color = AppTheme.success;
        label = 'PAID';
        icon = Icons.check_circle_outline;
        break;
      case InvoiceStatus.pending:
        color = AppTheme.warning;
        label = 'PENDING';
        icon = Icons.schedule;
        break;
      case InvoiceStatus.expired:
        color = AppTheme.textMuted;
        label = 'EXPIRED';
        icon = Icons.cancel_outlined;
        break;
      case InvoiceStatus.cancelled:
        color = AppTheme.danger;
        label = 'VOID';
        icon = Icons.block_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
