import 'package:flutter/material.dart';
import '../../core/models/invoice.dart';

class StatusPill extends StatelessWidget {
  final InvoiceStatus status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case InvoiceStatus.paid:
        bg = const Color(0xFF064E3B);
        fg = const Color(0xFF34D399);
        label = 'LUNAS';
        icon = Icons.check_circle_rounded;
        break;
      case InvoiceStatus.pending:
        bg = const Color(0xFF78350F);
        fg = const Color(0xFFFBBF24);
        label = 'MENUNGGU';
        icon = Icons.access_time_filled_rounded;
        break;
      case InvoiceStatus.expired:
        bg = const Color(0xFF334155);
        fg = const Color(0xFF94A3B8);
        label = 'KADALUARSA';
        icon = Icons.hourglass_disabled_rounded;
        break;
      case InvoiceStatus.cancelled:
        bg = const Color(0xFF7F1D1D);
        fg = const Color(0xFFF87171);
        label = 'DIBATALKAN';
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
