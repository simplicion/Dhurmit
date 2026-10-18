import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/money/app_money.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../core/widgets/status_badge.dart';
import '../../collections/presentation/record_collection_bottom_sheet.dart';

enum CalendarFilter { all, overdue, pending, paid }

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
  CalendarFilter _selectedFilter = CalendarFilter.all;

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

  void _openRecordCollection(String? memberId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => RecordCollectionBottomSheet(
        committeeId: widget.committeeId,
        initialMemberId: memberId,
        onSuccess: _fetchCalendar,
      ),
    );
  }

  List<dynamic> _getFilteredDays() {
    if (_selectedFilter == CalendarFilter.all) return _days;

    return _days.where((day) {
      final dayMap = day as Map<String, dynamic>;
      final int overdueCount = (dayMap['overdueCount'] as num?)?.toInt() ?? 0;
      final items = (dayMap['items'] as List?) ?? [];
      final int paidOnTime = (dayMap['paidOnTimeCount'] as num?)?.toInt() ?? 0;
      final int paidLate = (dayMap['paidLateCount'] as num?)?.toInt() ?? 0;
      final bool isFullyPaid = items.isNotEmpty && (paidOnTime + paidLate == items.length);

      switch (_selectedFilter) {
        case CalendarFilter.overdue:
          return overdueCount > 0;
        case CalendarFilter.pending:
          return !isFullyPaid && overdueCount == 0;
        case CalendarFilter.paid:
          return isFullyPaid;
        case CalendarFilter.all:
          return true;
      }
    }).toList();
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
        subtitle: 'Once the committee is activated, all due dates and member obligations will appear here.',
        icon: Icons.calendar_month_outlined,
      );
    }

    // Compute high-level calendar stats
    int totalOverdueDays = 0;
    int totalOverdueMembers = 0;
    BigInt totalCalendarOutstanding = BigInt.zero;

    for (final day in _days) {
      final dayMap = day as Map<String, dynamic>;
      final int overdue = (dayMap['overdueCount'] as num?)?.toInt() ?? 0;
      if (overdue > 0) {
        totalOverdueDays++;
        totalOverdueMembers += overdue;
      }
      final outStr = dayMap['totalOutstandingMinor'];
      if (outStr != null) {
        totalCalendarOutstanding += BigInt.tryParse(outStr.toString()) ?? BigInt.zero;
      }
    }

    final filteredDays = _getFilteredDays();

    return RefreshIndicator(
      onRefresh: _fetchCalendar,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Header Summary Card
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: totalOverdueDays > 0
                  ? tokens.unpaidOverdueContainer.withValues(alpha: 0.25)
                  : tokens.surfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: totalOverdueDays > 0
                    ? tokens.unpaidOverdue.withValues(alpha: 0.3)
                    : tokens.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: totalOverdueDays > 0
                        ? tokens.unpaidOverdueContainer
                        : tokens.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    totalOverdueDays > 0
                        ? Icons.warning_amber_rounded
                        : Icons.event_available_rounded,
                    color: totalOverdueDays > 0 ? tokens.unpaidOverdue : tokens.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        totalOverdueDays > 0
                            ? '$totalOverdueMembers Overdue Member Obligations'
                            : 'All Scheduled Dates Healthy',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: totalOverdueDays > 0
                              ? tokens.unpaidOverdue
                              : tokens.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total Outstanding: ${AppMoney.fromPaisa(totalCalendarOutstanding).formatShort()} across ${_days.length} due dates',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All (${_days.length})',
                  filter: CalendarFilter.all,
                  tokens: tokens,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Overdue ($totalOverdueDays)',
                  filter: CalendarFilter.overdue,
                  tokens: tokens,
                  isWarning: totalOverdueDays > 0,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Pending',
                  filter: CalendarFilter.pending,
                  tokens: tokens,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Completed',
                  filter: CalendarFilter.paid,
                  tokens: tokens,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Empty filter state
          if (filteredDays.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.filter_list_off_rounded, size: 40, color: tokens.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(
                      'No due dates match the selected filter',
                      style: TextStyle(fontSize: 14, color: tokens.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Days Cards List
            ...filteredDays.map((day) {
              final dayMap = day as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _DayScheduleCard(
                  key: ValueKey(dayMap['date']),
                  day: dayMap,
                  onRecordCollection: _openRecordCollection,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required CalendarFilter filter,
    required dynamic tokens,
    bool isWarning = false,
  }) {
    final isSelected = _selectedFilter == filter;
    final Color activeColor = isWarning ? tokens.unpaidOverdue : tokens.primary;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedFilter = filter);
      },
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? (isWarning ? tokens.unpaidOverdue : tokens.onPrimary)
            : tokens.onSurfaceVariant,
      ),
      backgroundColor: tokens.surface,
      selectedColor: isWarning
          ? tokens.unpaidOverdueContainer
          : activeColor,
      side: BorderSide(
        color: isSelected
            ? activeColor
            : tokens.outlineVariant,
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }
}

class _DayScheduleCard extends StatefulWidget {
  final Map<String, dynamic> day;
  final void Function(String? memberId) onRecordCollection;

  const _DayScheduleCard({
    super.key,
    required this.day,
    required this.onRecordCollection,
  });

  @override
  State<_DayScheduleCard> createState() => _DayScheduleCardState();
}

class _DayScheduleCardState extends State<_DayScheduleCard> {
  late bool _isExpanded;

  static const List<String> _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const List<String> _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  @override
  void initState() {
    super.initState();
    final overdueCount = (widget.day['overdueCount'] as num?)?.toInt() ?? 0;
    // Overdue dates are initially expanded to draw manager attention
    _isExpanded = overdueCount > 0;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;
    final dateStr = (widget.day['date'] as String?) ?? '';
    final items = (widget.day['items'] as List?) ?? [];
    final totalDue = AppMoney.fromPaisa(widget.day['totalDueMinor']);
    final totalOutstanding = AppMoney.fromPaisa(widget.day['totalOutstandingMinor']);
    final totalCollected = AppMoney.fromPaisa(widget.day['totalCollectedMinor']);
    final int overdueCount = (widget.day['overdueCount'] as num?)?.toInt() ?? 0;
    final int paidOnTime = (widget.day['paidOnTimeCount'] as num?)?.toInt() ?? 0;
    final int paidLate = (widget.day['paidLateCount'] as num?)?.toInt() ?? 0;
    final bool isCompleted = items.isNotEmpty && (paidOnTime + paidLate == items.length);

    // Parse date safely
    final parsedDate = DateTime.tryParse(dateStr);
    final String monthAbbr = (parsedDate != null && parsedDate.month >= 1 && parsedDate.month <= 12)
        ? _months[parsedDate.month - 1]
        : 'DATE';
    final String dayNum = parsedDate != null ? '${parsedDate.day}' : dateStr.split('-').last;
    final String weekday = (parsedDate != null && parsedDate.weekday >= 1 && parsedDate.weekday <= 7)
        ? _weekdays[parsedDate.weekday - 1]
        : '';
    final String formattedTitle = parsedDate != null
        ? '$weekday, ${parsedDate.day} ${_monthNames[parsedDate.month - 1]} ${parsedDate.year}'
        : dateStr;

    // Visual card accents based on state
    Color cardBorder = tokens.outlineVariant;
    Color cardBg = tokens.surface;
    Color dateBadgeBg = tokens.primaryContainer;
    Color dateBadgeFg = tokens.primary;

    if (overdueCount > 0) {
      cardBorder = tokens.unpaidOverdue.withValues(alpha: 0.4);
      cardBg = tokens.unpaidOverdueContainer.withValues(alpha: 0.15);
      dateBadgeBg = tokens.unpaidOverdueContainer;
      dateBadgeFg = tokens.unpaidOverdue;
    } else if (isCompleted) {
      cardBorder = tokens.paidOnTime.withValues(alpha: 0.35);
      cardBg = tokens.paidOnTimeContainer.withValues(alpha: 0.12);
      dateBadgeBg = tokens.paidOnTimeContainer;
      dateBadgeFg = tokens.paidOnTime;
    }

    final double collectionProgress = totalDue.isPositive
        ? (totalCollected.toRupees() / totalDue.toRupees()).clamp(0.0, 1.0)
        : (isCompleted ? 1.0 : 0.0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: overdueCount > 0 ? 1.5 : 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row (Clickable)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Calendar Date Badge (fixed size, never overflows)
                  Container(
                    width: 50,
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: dateBadgeFg.withValues(alpha: 0.35)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          color: dateBadgeBg,
                          alignment: Alignment.center,
                          child: Text(
                            monthAbbr,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: dateBadgeFg,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            dayNum,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: tokens.onSurface,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (weekday.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              weekday,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: tokens.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Middle Content (Expanded, responsive, zero overflows)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row: Formatted Date + Badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                formattedTitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: tokens.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (overdueCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tokens.unpaidOverdueContainer,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: tokens.unpaidOverdue.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '$overdueCount Overdue',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.unpaidOverdue,
                                  ),
                                ),
                              )
                            else if (isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tokens.paidOnTimeContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Completed',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.paidOnTime,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Subtitle: Wrap metrics chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${items.length} ${items.length == 1 ? 'member' : 'members'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: tokens.onSurfaceVariant,
                              ),
                            ),
                            Text('•', style: TextStyle(fontSize: 10, color: tokens.onSurfaceVariant)),
                            Text(
                              'Due: ${totalDue.formatShort()}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: tokens.onSurfaceVariant,
                              ),
                            ),
                            Text('•', style: TextStyle(fontSize: 10, color: tokens.onSurfaceVariant)),
                            Text(
                              totalOutstanding.isPositive
                                  ? 'Unpaid: ${totalOutstanding.formatShort()}'
                                  : 'All Collected',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: totalOutstanding.isPositive
                                    ? (overdueCount > 0 ? tokens.unpaidOverdue : tokens.primary)
                                    : tokens.paidOnTime,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Trailing Chevron
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: tokens.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 12),

                  // Mini Collection Progress Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Collected: ${totalCollected.formatShort()}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: tokens.paidOnTime,
                              ),
                            ),
                            Text(
                              'Target: ${totalDue.formatShort()}',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: collectionProgress,
                            minHeight: 5,
                            backgroundColor: tokens.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isCompleted
                                  ? tokens.paidOnTime
                                  : (overdueCount > 0 ? tokens.unpaidOverdue : tokens.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Member Obligations List
                  ...items.map((item) {
                    final itemMap = item as Map<String, dynamic>;
                    final status = (itemMap['status'] as String?) ?? 'UPCOMING';
                    final due = AppMoney.fromPaisa(itemMap['dueAmountMinor']);
                    final outstanding = AppMoney.fromPaisa(itemMap['outstandingAmountMinor']);
                    final memberName = (itemMap['memberName'] as String?) ?? 'Member';
                    final memberId = itemMap['memberId'] as String?;
                    final bool isUnpaid = outstanding.isPositive;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tokens.outlineVariant.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: tokens.primaryContainer,
                            child: Text(
                              memberName.isNotEmpty ? memberName[0].toUpperCase() : 'M',
                              style: TextStyle(
                                fontSize: 12,
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Due: ${due.formatShort()} | Remaining: ${outstanding.formatShort()}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: tokens.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          StatusBadge(status: status, compact: true),
                          if (isUnpaid && memberId != null) ...[
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.add_card_rounded, size: 18),
                              color: tokens.primary,
                              tooltip: 'Record Collection',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => widget.onRecordCollection(memberId),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}
