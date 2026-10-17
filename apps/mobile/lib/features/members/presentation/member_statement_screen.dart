import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
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

  @override
  void initState() {
    super.initState();
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
        setState(() {
          _data = res as Map<String, dynamic>;
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
              : _buildContent(tokens),
    );
  }

  Widget _buildContent(AppColorTokens tokens) {
    final member = _data!['member'] as Map<String, dynamic>;
    final statement = _data!['statement'] as Map<String, dynamic>;
    final obligations = (statement['obligations'] as List?) ?? [];

    final totalDue = AppMoney.fromPaisa(statement['totalDueMinor']);
    final totalPaid = AppMoney.fromPaisa(statement['totalPaidMinor']);
    final totalOutstanding = AppMoney.fromPaisa(statement['totalOutstandingMinor']);
    final displayName = (member['displayName'] as String?) ?? 'Member';

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
          const SizedBox(height: 24),

          // Ledger Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                '${obligations.length} dues',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.onSurfaceVariant,
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
          else
            ...obligations.map((ob) => _buildObligationCard(ob as Map<String, dynamic>, tokens)),
        ],
      ),
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
      decoration: BoxDecoration(
        color: tokens.surface,
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
    );
  }
}
