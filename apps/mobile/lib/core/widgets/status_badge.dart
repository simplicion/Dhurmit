import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../money/app_money.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final BigInt? remainingMinor;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.status,
    this.remainingMinor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;

    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status.toUpperCase()) {
      case 'PAID_ON_TIME':
        bg = tokens.paidOnTimeContainer;
        fg = tokens.paidOnTime;
        icon = Icons.check_circle_rounded;
        label = 'Paid on time';
        break;
      case 'PAID_LATE':
        bg = tokens.paidLateContainer;
        fg = tokens.paidLate;
        icon = Icons.history_rounded;
        label = 'Paid late';
        break;
      case 'PARTIALLY_PAID':
        bg = tokens.partiallyPaidContainer;
        fg = tokens.partiallyPaid;
        icon = Icons.timelapse_rounded;
        final remainingStr = remainingMinor != null
            ? ' (${AppMoney.fromPaisa(remainingMinor!).formatShort()} left)'
            : '';
        label = 'Partial$remainingStr';
        break;
      case 'UNPAID_OVERDUE':
        bg = tokens.unpaidOverdueContainer;
        fg = tokens.unpaidOverdue;
        icon = Icons.warning_rounded;
        label = 'Overdue';
        break;
      case 'UPCOMING':
      default:
        bg = tokens.upcomingContainer;
        fg = tokens.upcoming;
        icon = Icons.schedule_rounded;
        label = 'Upcoming';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 15, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
