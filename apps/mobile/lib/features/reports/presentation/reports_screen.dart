import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/money/app_money.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/state_widgets.dart';

import '../../../core/sync/offline_cache_store.dart';

class ReportsScreen extends StatefulWidget {
  final String? committeeId;

  const ReportsScreen({super.key, this.committeeId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _committees = [];
  String? _selectedCommitteeId;
  Map<String, dynamic>? _summary;
  List<dynamic> _overdueList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedCommitteeId = widget.committeeId;
    _initReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final cacheStore = context.read<OfflineCacheStore>();
    final authState = context.read<AuthState>();
    final wsId = authState.activeWorkspace?['id']?.toString() ?? 'default';

    List<dynamic> list = [];
    try {
      final client = authState.apiClient;
      final commRes = await client.get('/committees');
      if (commRes is List) {
        list = commRes;
        await cacheStore.cacheCommittees(wsId, list.cast<Map<String, dynamic>>());
      }
    } catch (_) {
      // Offline fallback: load cached committees
      list = cacheStore.getCachedCommittees(wsId);
    }

    if (list.isEmpty) {
      list = cacheStore.getCachedCommittees(wsId);
    }

    if (mounted) {
      setState(() {
        _committees = list;
        if (_selectedCommitteeId == null && list.isNotEmpty) {
          _selectedCommitteeId = (list.first as Map<String, dynamic>)['id'] as String?;
        }
      });

      if (_selectedCommitteeId != null) {
        await _loadCommitteeReports(_selectedCommitteeId!);
      } else {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
    }
  }

  Future<void> _loadCommitteeReports(String committeeId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final cacheStore = context.read<OfflineCacheStore>();
    final authState = context.read<AuthState>();

    try {
      final client = authState.apiClient;
      final sumRes = await client.get('/committees/$committeeId/reports/summary');
      final overRes = await client.get('/committees/$committeeId/reports/overdue');

      if (mounted) {
        setState(() {
          _summary = sumRes as Map<String, dynamic>;
          _overdueList = (overRes as Map<String, dynamic>)['overdueMembers'] as List? ?? [];
          _isLoading = false;
          _error = null;
        });
        return;
      }
    } catch (_) {
      // Offline: Calculate summary and overdue figures dynamically from local cache
      final obligations = cacheStore.getCachedObligations(committeeId);
      final collections = cacheStore.getCachedCollections(committeeId);
      final members = cacheStore.getCachedMembers(committeeId);

      BigInt totalExpected = BigInt.zero;
      BigInt totalCollected = BigInt.zero;
      BigInt totalOutstanding = BigInt.zero;
      final List<Map<String, dynamic>> overdueMembers = [];

      for (final ob in obligations) {
        final due = BigInt.tryParse((ob['dueAmountMinor'] ?? '0').toString()) ?? BigInt.zero;
        final allocated = BigInt.tryParse((ob['alreadyAllocatedMinor'] ?? '0').toString()) ?? BigInt.zero;
        final remaining = BigInt.tryParse((ob['remainingAmountMinor'] ?? '0').toString()) ?? (due > allocated ? due - allocated : BigInt.zero);
        final status = ob['status']?.toString() ?? '';

        totalExpected += due;
        totalCollected += allocated;

        if (remaining > BigInt.zero) {
          totalOutstanding += remaining;
        }

        if (remaining > BigInt.zero && (status == 'UNPAID_OVERDUE' || status == 'PARTIALLY_PAID')) {
          final memberName = ob['memberName'] ?? 'Member';
          final memberId = ob['memberId'] ?? '';
          overdueMembers.add({
            'memberId': memberId,
            'memberName': memberName,
            'overdueCount': 1,
            'totalOverdueMinor': remaining.toString(),
            'oldestOverdueDate': ob['dueDate'] ?? '',
          });
        }
      }

      if (mounted) {
        setState(() {
          _summary = {
            'totalExpectedMinor': totalExpected.toString(),
            'totalCollectedMinor': totalCollected.toString(),
            'totalOutstandingMinor': totalOutstanding.toString(),
            'memberCount': members.isNotEmpty ? members.length : 1,
            'totalCollectionsCount': collections.length,
            'isOfflineCalculated': true,
          };
          _overdueList = overdueMembers;
          _isLoading = false;
          _error = null;
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
        title: const Text('Reports & Audit'),
        backgroundColor: tokens.surface,
        foregroundColor: tokens.onSurface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: tokens.primary,
          unselectedLabelColor: tokens.onSurfaceVariant,
          indicatorColor: tokens.primary,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Overdue & Arrears'),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingState(message: 'Generating committee reports...')
          : _error != null
              ? ErrorState(message: _error!, onRetry: _initReports)
              : _committees.isEmpty
                  ? const EmptyState(
                      title: 'No Committees Found',
                      subtitle: 'Create and activate a committee to view reports.',
                      icon: Icons.bar_chart_rounded,
                    )
                  : Column(
                      children: [
                        // Committee Selector
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: tokens.surface,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedCommitteeId,
                            decoration: const InputDecoration(
                              labelText: 'Select Committee',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: _committees.map<DropdownMenuItem<String>>((dynamic c) {
                              final map = c as Map<String, dynamic>;
                              return DropdownMenuItem<String>(
                                value: map['id'] as String,
                                child: Text((map['name'] as String?) ?? 'Unnamed'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedCommitteeId = val;
                                });
                                _loadCommitteeReports(val);
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildSummaryTab(tokens),
                              _buildOverdueTab(tokens),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildSummaryTab(AppColorTokens tokens) {
    if (_summary == null) {
      return const Center(child: Text('No summary data'));
    }

    final totalExpected = AppMoney.fromPaisa(_summary!['totalExpectedMinor']);
    final totalCollected = AppMoney.fromPaisa(_summary!['totalCollectedMinor']);
    final totalOutstanding = AppMoney.fromPaisa(_summary!['totalOutstandingMinor']);
    final memberCount = _summary!['memberCount'] ?? 0;
    final collectionCount = _summary!['totalCollectionsCount'] ?? 0;

    return RefreshIndicator(
      onRefresh: () => _loadCommitteeReports(_selectedCommitteeId!),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Legal boundary disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.gavel_rounded, size: 20, color: tokens.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Software recordkeeping tool. Not a banking, escrow, or money transmission service.',
                    style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Total metrics
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_summary!['committeeName'] as String?) ?? 'Committee',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: tokens.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _buildReportRow('Total Expected Obligation', totalExpected.formatShort(), tokens),
                const Divider(),
                _buildReportRow('Total Settled Collections', totalCollected.formatShort(), tokens, color: tokens.paidOnTime),
                const Divider(),
                _buildReportRow('Total Outstanding Balance', totalOutstanding.formatShort(), tokens, color: tokens.unpaidOverdue, bold: true),
                const Divider(),
                _buildReportRow('Active Enrolled Members', memberCount.toString(), tokens),
                const Divider(),
                _buildReportRow('Total Recorded Collections', collectionCount.toString(), tokens),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, String value, AppColorTokens tokens, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: tokens.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color ?? tokens.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueTab(AppColorTokens tokens) {
    if (_overdueList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 54, color: tokens.paidOnTime),
              const SizedBox(height: 16),
              Text(
                'No Overdue Dues!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tokens.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'All obligations are either settled on time or upcoming.',
                textAlign: TextAlign.center,
                style: TextStyle(color: tokens.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadCommitteeReports(_selectedCommitteeId!),
      child: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: _overdueList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _overdueList[index];
          final amount = AppMoney.fromPaisa(item['totalOverdueMinor']);
          final oldestDate = item['oldestUnpaidDueDate'] != null
              ? item['oldestUnpaidDueDate'].toString().split('T')[0]
              : 'N/A';

          return Container(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.unpaidOverdue.withValues(alpha: 0.3)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: tokens.unpaidOverdueContainer,
                child: Icon(Icons.warning_amber_rounded, color: tokens.unpaidOverdue),
              ),
              title: Text(
                (item['memberName'] as String?) ?? 'Member',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${item['overdueObligationsCount']} overdue due(s) • Oldest: $oldestDate',
                style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount.formatShort(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: tokens.unpaidOverdue,
                    ),
                  ),
                  Text('Statement >', style: TextStyle(fontSize: 10, color: tokens.primary)),
                ],
              ),
              onTap: () {
                context.push('/committees/$_selectedCommitteeId/members/${item['memberId']}/statement');
              },
            ),
          );
        },
      ),
    );
  }
}
