import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/location/country_provider.dart';
import '../../../core/money/app_money.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../core/widgets/status_badge.dart';

class MemberStatementScreen extends StatefulWidget {
  final String committeeId;
  final String memberId;

  const MemberStatementScreen({
    super.key,
    required this.committeeId,
    required this.memberId,
  });

  @override
  State<MemberStatementScreen> createState() => _MemberStatementScreenState();
}

class _MemberStatementScreenState extends State<MemberStatementScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  bool _isCalendarView = true;
  late DateTime _focusedMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _fetchStatement();
  }

  Future<void> _fetchStatement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = context.read<AuthState>().apiClient;
      final res = await client.get(
        '/committees/${widget.committeeId}/members/${widget.memberId}/statement',
      );
      if (mounted) {
        final data = res as Map<String, dynamic>;
        DateTime? initialFocus;
        final statement = data['statement'] as Map<String, dynamic>?;
        final obligations = (statement?['obligations'] as List?) ?? [];
        if (obligations.isNotEmpty) {
          final firstDueDate = obligations.first['dueDate']?.toString();
          if (firstDueDate != null) {
            final parsed = DateTime.tryParse(firstDueDate);
            if (parsed != null) {
              initialFocus = DateTime(parsed.year, parsed.month);
              _selectedDate ??= DateTime(parsed.year, parsed.month, parsed.day);
            }
          }
        }

        setState(() {
          _data = data;
          if (initialFocus != null) {
            _focusedMonth = initialFocus;
          }
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

  Map<String, List<Map<String, dynamic>>> _groupObligationsByDate(List<dynamic> obligations) {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final ob in obligations) {
      if (ob is Map<String, dynamic>) {
        final dateStr = ob['dueDate']?.toString();
        if (dateStr != null && dateStr.isNotEmpty) {
          map.putIfAbsent(dateStr, () => []).add(ob);
        }
      }
    }
    return map;
  }

  void _showDateDetailsSheet(DateTime date, List<Map<String, dynamic>> dateObligations, AppColorTokens tokens) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(date);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: tokens.onSurface,
                          ),
                        ),
                        Text(
                          dateObligations.isNotEmpty
                              ? '${dateObligations.length} obligation(s) on this date'
                              : 'No scheduled obligations',
                          style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),
              if (dateObligations.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No dues or payments scheduled for this date.',
                      style: TextStyle(fontSize: 14, color: tokens.onSurfaceVariant),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: dateObligations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _buildObligationCard(dateObligations[i], tokens),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;
    final country = context.watch<CountryProvider>().activeCountry;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: const Text('Member Statement'),
        backgroundColor: tokens.surface,
        foregroundColor: tokens.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchStatement,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingState(message: 'Loading ledger statement...')
          : _error != null
              ? ErrorState(message: _error!, onRetry: _fetchStatement)
              : _buildContent(tokens, country),
    );
  }

  Widget _buildContent(AppColorTokens tokens, dynamic country) {
    final member = _data!['member'] as Map<String, dynamic>;
    final statement = _data!['statement'] as Map<String, dynamic>;
    final obligations = (statement['obligations'] as List?) ?? [];

    final totalDue = AppMoney.fromPaisa(statement['totalDueMinor']);
    final totalPaid = AppMoney.fromPaisa(statement['totalPaidMinor']);
    final totalOutstanding = AppMoney.fromPaisa(statement['totalOutstandingMinor']);
    final displayName = (member['displayName'] as String?) ?? 'Member';

    final groupedDues = _groupObligationsByDate(obligations);

    return RefreshIndicator(
      onRefresh: _fetchStatement,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Member Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.outlineVariant),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: tokens.primaryContainer,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: tokens.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: tokens.onSurface,
                        ),
                      ),
                      if (member['phone'] != null && member['phone'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          member['phone'].toString(),
                          style: TextStyle(
                            fontSize: 13,
                            color: tokens.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Financial Summary
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total Due',
                  totalDue.formatShort(),
                  tokens.onSurfaceVariant,
                  tokens.surfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryItem(
                  'Total Paid',
                  totalPaid.formatShort(),
                  tokens.paidOnTime,
                  tokens.paidOnTimeContainer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryItem(
                  'Outstanding',
                  totalOutstanding.formatShort(),
                  tokens.unpaidOverdue,
                  tokens.unpaidOverdueContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // View Selector & Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule & Collections',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: tokens.onSurface,
                    ),
                  ),
                  Text(
                    '${obligations.length} dues across calendar',
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              // Calendar vs List Toggle
              Container(
                decoration: BoxDecoration(
                  color: tokens.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _isCalendarView = true),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isCalendarView ? tokens.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 14,
                              color: _isCalendarView ? tokens.onPrimary : tokens.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Calendar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _isCalendarView ? tokens.onPrimary : tokens.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _isCalendarView = false),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: !_isCalendarView ? tokens.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.view_list_rounded,
                              size: 14,
                              color: !_isCalendarView ? tokens.onPrimary : tokens.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'List',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: !_isCalendarView ? tokens.onPrimary : tokens.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (obligations.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: tokens.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'No obligations generated yet.',
                  style: TextStyle(color: tokens.onSurfaceVariant),
                ),
              ),
            )
          else if (_isCalendarView)
            _buildInteractiveCalendar(groupedDues, tokens)
          else
            ...obligations.map((ob) => _buildObligationCard(ob as Map<String, dynamic>, tokens)),
        ],
      ),
    );
  }

  Widget _buildInteractiveCalendar(
    Map<String, List<Map<String, dynamic>>> groupedDues,
    AppColorTokens tokens,
  ) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0, Monday = 1...

    final selectedDateStr = _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : null;
    final selectedObligations = selectedDateStr != null ? groupedDues[selectedDateStr] ?? [] : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Month Navigation Header ───
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.outlineVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous Month',
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(year, month - 1);
                  });
                },
              ),
              PopupMenuButton<int>(
                initialValue: month,
                tooltip: 'Select Month',
                onSelected: (m) {
                  setState(() {
                    _focusedMonth = DateTime(year, m);
                  });
                },
                itemBuilder: (ctx) => List.generate(12, (i) {
                  final dt = DateTime(year, i + 1);
                  return PopupMenuItem(
                    value: i + 1,
                    child: Text(DateFormat('MMMM yyyy').format(dt)),
                  );
                }),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_focusedMonth),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: tokens.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down_rounded, color: tokens.onSurface),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next Month',
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(year, month + 1);
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ─── Day of Week Header ───
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: tokens.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Expanded(child: Center(child: Text('Sun', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
              Expanded(child: Center(child: Text('Mon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
              Expanded(child: Center(child: Text('Tue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
              Expanded(child: Center(child: Text('Wed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
              Expanded(child: Center(child: Text('Thu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
              Expanded(child: Center(child: Text('Fri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
              Expanded(child: Center(child: Text('Sat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ─── Calendar Grid (7 columns) ───
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.outlineVariant),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42, // 6 weeks * 7 days
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.88,
            ),
            itemBuilder: (context, index) {
              final dayOffset = index - startingWeekday + 1;
              if (dayOffset < 1 || dayOffset > daysInMonth) {
                return const SizedBox.shrink();
              }

              final cellDate = DateTime(year, month, dayOffset);
              final dateKey = DateFormat('yyyy-MM-dd').format(cellDate);
              final dayDues = groupedDues[dateKey] ?? [];
              final hasDues = dayDues.isNotEmpty;

              final isSelected = _selectedDate != null &&
                  _selectedDate!.year == cellDate.year &&
                  _selectedDate!.month == cellDate.month &&
                  _selectedDate!.day == cellDate.day;

              final isToday = DateTime.now().year == cellDate.year &&
                  DateTime.now().month == cellDate.month &&
                  DateTime.now().day == cellDate.day;

              // Determine cell color from due status
              Color? badgeColor;
              Color? cellBg;
              if (hasDues) {
                final status = dayDues.first['status']?.toString();
                if (status == 'UNPAID_OVERDUE') {
                  badgeColor = tokens.unpaidOverdue;
                  cellBg = tokens.unpaidOverdueContainer.withValues(alpha: 0.35);
                } else if (status == 'PAID_ON_TIME' || status == 'PAID_LATE') {
                  badgeColor = tokens.paidOnTime;
                  cellBg = tokens.paidOnTimeContainer.withValues(alpha: 0.35);
                } else if (status == 'PARTIALLY_PAID') {
                  badgeColor = tokens.partiallyPaid;
                  cellBg = tokens.partiallyPaidContainer.withValues(alpha: 0.35);
                } else {
                  badgeColor = tokens.primary;
                  cellBg = tokens.primaryContainer.withValues(alpha: 0.25);
                }
              }

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedDate = cellDate;
                  });
                  _showDateDetailsSheet(cellDate, dayDues, tokens);
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? tokens.primary.withValues(alpha: 0.15)
                        : cellBg ?? Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? tokens.primary
                          : isToday
                              ? tokens.secondary
                              : hasDues
                                  ? (badgeColor ?? tokens.outlineVariant)
                                  : tokens.outlineVariant.withValues(alpha: 0.4),
                      width: isSelected || isToday ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayOffset',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected || hasDues ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? tokens.primary : tokens.onSurface,
                        ),
                      ),
                      if (hasDues) ...[
                        const SizedBox(height: 3),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // ─── Selected Date Bottom Details Card ───
        if (_selectedDate != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.event_note_rounded, size: 18, color: tokens.primary),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: tokens.onSurface,
                          ),
                        ),
                      ],
                    ),
                    if (selectedObligations.isNotEmpty)
                      StatusBadge(status: selectedObligations.first['status']?.toString() ?? 'UPCOMING'),
                  ],
                ),
                const Divider(height: 18),
                if (selectedObligations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No dues or collections scheduled on this date.',
                      style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
                    ),
                  )
                else
                  ...selectedObligations.map((ob) => _buildObligationCard(ob, tokens)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSummaryItem(String label, String amount, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildObligationCard(Map<String, dynamic> ob, AppColorTokens tokens) {
    final status = ob['status'] as String? ?? 'UPCOMING';
    final dueAmount = AppMoney.fromPaisa(ob['amountMinor']);
    final outstandingAmount = AppMoney.fromPaisa(ob['outstandingMinor']);
    final allocations = (ob['allocations'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.outlineVariant),
          ),
          child: ExpansionTile(
        initiallyExpanded: allocations.isNotEmpty || status == 'UNPAID_OVERDUE',
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Text(
              '#${ob['sequenceNumber'] ?? '-'} Due: ${ob['dueDate']}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: tokens.onSurface,
              ),
            ),
            const Spacer(),
            StatusBadge(status: status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Obligation: ${dueAmount.formatShort()}',
                style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
              ),
              Text(
                outstandingAmount.minorUnits > BigInt.zero
                    ? 'Remaining: ${outstandingAmount.formatShort()}'
                    : 'Settled',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: outstandingAmount.minorUnits > BigInt.zero
                      ? tokens.unpaidOverdue
                      : tokens.paidOnTime,
                ),
              ),
            ],
          ),
        ),
        children: [
          const Divider(height: 16),
          if (allocations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No payments allocated yet to this due date.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: tokens.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Allocated Receipts (${allocations.length}):',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: tokens.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...allocations.map((alloc) {
              final allocMap = alloc as Map<String, dynamic>;
              final allocAmount = AppMoney.fromPaisa(allocMap['amountMinor']);
              final receivedAtStr = allocMap['receivedAt'] != null
                  ? allocMap['receivedAt'].toString().split('T')[0]
                  : 'N/A';
              final method = allocMap['methodLabel'] ?? 'Cash';
              final ref = allocMap['reference'] != null ? ' (Ref: ${allocMap['reference']})' : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 16, color: tokens.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paid on $receivedAtStr via $method$ref',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: tokens.onSurface,
                            ),
                          ),
                          Text(
                            'Allocated to this obligation',
                            style: TextStyle(
                              fontSize: 10,
                              color: tokens.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      allocAmount.formatShort(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: tokens.paidOnTime,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
        ),
      ),
    );
  }
}
