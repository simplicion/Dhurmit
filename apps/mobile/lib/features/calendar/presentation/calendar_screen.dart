import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/money/app_money.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../core/widgets/status_badge.dart';

class CalendarScreen extends StatefulWidget {
  final String committeeId;

  const CalendarScreen({super.key, required this.committeeId});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _days = [];

  @override
  void initState() {
    super.initState();
    _fetchCalendar();
  }

  Future<void> _fetchCalendar() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = context.read<AuthState>().apiClient;
      final res = await client.get('/committees/${widget.committeeId}/calendar');
      if (mounted) {
        final days = (res as Map<String, dynamic>)['days'] as List? ?? [];
        setState(() {
          _days = days;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;

    if (_isLoading) {
      return const LoadingStateWidget(message: 'Loading committee calendar...');
    }

    if (_error != null) {
      return ErrorStateWidget(message: _error!, onRetry: _fetchCalendar);
    }

    if (_days.isEmpty) {
      return const EmptyStateWidget(
        title: 'No Due Dates Generated',
        subtitle: 'Once the committee is activated, all due dates and member obligations will be scheduled here.',
        icon: Icons.calendar_month_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCalendar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: _days.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final day = _days[index] as Map<String, dynamic>;
          final dateStr = (day['date'] as String?) ?? '';
          final items = (day['items'] as List?) ?? [];
          final totalDue = AppMoney.fromPaisa(day['totalDueMinor']);
          final totalOutstanding = AppMoney.fromPaisa(day['totalOutstandingMinor']);
          final int overdueCount = (day['overdueCount'] as num?)?.toInt() ?? 0;
          final int paidOnTimeCount = (day['paidOnTimeCount'] as num?)?.toInt() ?? 0;
          final int paidLateCount = (day['paidLateCount'] as num?)?.toInt() ?? 0;

          // Determine overall day severity
          Color headerBg = tokens.surface;
          if (overdueCount > 0) {
            headerBg = tokens.unpaidOverdueContainer.withValues(alpha: 0.3);
          } else if (items.isNotEmpty && (paidOnTimeCount + paidLateCount == items.length)) {
            headerBg = tokens.paidOnTimeContainer.withValues(alpha: 0.3);
          }

          return Container(
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: overdueCount > 0
                    ? tokens.unpaidOverdue.withValues(alpha: 0.3)
                    : tokens.outlineVariant,
              ),
            ),
            child: ExpansionTile(
              initiallyExpanded: overdueCount > 0,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_rounded, size: 20, color: tokens.primary),
                    Text(
                      dateStr.split('-').length == 3 ? dateStr.split('-')[2] : '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: tokens.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              title: Row(
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: tokens.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (overdueCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tokens.unpaidOverdueContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$overdueCount Overdue',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: tokens.unpaidOverdue,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '${items.length} members • Due: ${totalDue.formatShort()} • Unpaid: ${totalOutstanding.formatShort()}',
                  style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
                ),
              ),
              children: [
                const Divider(height: 16),
                // Member items list for this date
                ...items.map((item) {
                  final itemMap = item as Map<String, dynamic>;
                  final status = (itemMap['status'] as String?) ?? 'UPCOMING';
                  final due = AppMoney.fromPaisa(itemMap['dueAmountMinor']);
                  final outstanding = AppMoney.fromPaisa(itemMap['outstandingAmountMinor']);
                  final memberName = (itemMap['memberName'] as String?) ?? 'Member';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: tokens.primaryContainer,
                          child: Text(
                            memberName.isNotEmpty ? memberName[0].toUpperCase() : 'M',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: tokens.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                memberName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                'Due: ${due.formatShort()} | Remaining: ${outstanding.formatShort()}',
                                style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(status: status),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
