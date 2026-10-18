import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/money/app_money.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../members/presentation/member_list_screen.dart';
import '../../calendar/presentation/calendar_screen.dart';
import '../../collections/presentation/collection_history_screen.dart';
import '../../collections/presentation/record_collection_bottom_sheet.dart';
import '../../bidding/presentation/bidding_rounds_screen.dart';

class CommitteeDashboardScreen extends StatefulWidget {
  final String committeeId;

  const CommitteeDashboardScreen({super.key, required this.committeeId});

  @override
  State<CommitteeDashboardScreen> createState() => _CommitteeDashboardScreenState();
}

class _CommitteeDashboardScreenState extends State<CommitteeDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _committee;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = context.read<AuthState>().apiClient;
      final res = await client.get('/committees/${widget.committeeId}/dashboard');
      if (mounted) {
        setState(() {
          _committee = res as Map<String, dynamic>;
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

  Future<void> _activateCommittee() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activate Committee?'),
        content: const Text(
          'Activating this committee will snapshot the configuration and generate immutable contribution obligations for all enrolled members.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Activate')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final client = context.read<AuthState>().apiClient;
    try {
      await client.post('/committees/${widget.committeeId}/activate');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Committee activated successfully!')),
      );
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  void _openRecordCollectionSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => RecordCollectionBottomSheet(
        committeeId: widget.committeeId,
        onSuccess: () {
          _loadDashboard();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Committee')),
        body: const LoadingStateWidget(message: 'Loading dashboard...'),
      );
    }

    if (_error != null || _committee == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Committee')),
        body: ErrorStateWidget(
          message: _error ?? 'Failed to load committee',
          onRetry: _loadDashboard,
        ),
      );
    }

    final isDraft = _committee!['status'] == 'DRAFT';
    final String? code = _committee!['code'] as String?;
    final bool isOrganizer = context.watch<AuthState>().isOrganizer;
    final expected = AppMoney.fromPaisa(_committee!['totalExpectedMinor'] ?? '0');
    final collected = AppMoney.fromPaisa(_committee!['totalCollectedMinor'] ?? '0');
    final outstanding = AppMoney.fromPaisa(_committee!['totalOutstandingMinor'] ?? '0');
    final int overdueCount = (_committee!['overdueMembersCount'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (_committee!['name'] as String?) ?? 'Committee',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            if (code != null && code.isNotEmpty)
              Text(
                'CODE: $code',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: tokens.primary,
                ),
              ),
          ],
        ),
        actions: [
          if (code != null && code.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: 'Copy Committee Code',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Committee Code "$code" copied to clipboard! Share it with members.'),
                    backgroundColor: tokens.primary,
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDashboard,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: tokens.primary,
          unselectedLabelColor: tokens.onSurfaceVariant,
          indicatorColor: tokens.primary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Members'),
            Tab(text: 'Calendar'),
            Tab(text: 'Release Bets'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Overview Tab
          RefreshIndicator(
            onRefresh: _loadDashboard,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (code != null && code.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: tokens.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tokens.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.vpn_key_rounded, color: tokens.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Committee Code for Members', style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant)),
                                Text(
                                  code,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3,
                                    color: tokens.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              side: BorderSide(color: tokens.primary),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: const Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Committee Code "$code" copied!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (isDraft) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tokens.paidLateContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: tokens.paidLate),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'This committee is in Draft. Add members and click Activate to generate obligations.',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Financial Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Collected',
                          amount: collected.formatShort(),
                          color: tokens.paidOnTime,
                          bgColor: tokens.paidOnTimeContainer,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Outstanding',
                          amount: outstanding.formatShort(),
                          color: tokens.unpaidOverdue,
                          bgColor: tokens.unpaidOverdueContainer,
                          icon: Icons.error_outline_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMetricCard(
                    title: 'Total Expected Contributions',
                    amount: expected.format(),
                    color: tokens.primary,
                    bgColor: tokens.primaryContainer,
                    icon: Icons.calculate_outlined,
                  ),
                  const SizedBox(height: 16),
                  // Overdue warning banner
                  if (overdueCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tokens.unpaidOverdueContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tokens.unpaidOverdue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: tokens.unpaidOverdue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$overdueCount Overdue Member${overdueCount > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: tokens.unpaidOverdue,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Members have missed one or more scheduled due dates.',
                                  style: TextStyle(fontSize: 12, color: tokens.onSurface),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Main Action Buttons
                  if (isDraft)
                    PrimaryButton(
                      label: 'Activate Committee',
                      icon: Icons.rocket_launch_rounded,
                      onPressed: _activateCommittee,
                    )
                  else
                    PrimaryButton(
                      label: 'Record Collection',
                      icon: Icons.add_card_rounded,
                      onPressed: _openRecordCollectionSheet,
                    ),
                  const SizedBox(height: 24),
                  // Recent collections
                  Text(
                    'Recent Collections',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: tokens.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildRecentCollectionsList(tokens),
                ],
              ),
            ),
          ),
          // Members Tab
          MemberListScreen(
            committeeId: widget.committeeId,
            isDraft: isDraft,
            onMemberAdded: _loadDashboard,
          ),
          // Calendar Tab
          CalendarScreen(committeeId: widget.committeeId),
          // Release Bets / Chit Fund Bidding Tab
          BiddingRoundsScreen(
            committeeId: widget.committeeId,
            isOrganizer: isOrganizer,
          ),
          // History Tab
          CollectionHistoryScreen(committeeId: widget.committeeId),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String amount,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCollectionsList(AppColorTokens tokens) {
    final recents = (_committee!['recentCollections'] as List?) ?? [];
    if (recents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            'No collections recorded yet.',
            style: TextStyle(fontSize: 13, color: tokens.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recents.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = recents[index];
        final amount = AppMoney.fromPaisa(c['amount_minor']);
        final isReversed = c['reversal_status'] == 'REVERSED';

        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: isReversed ? tokens.unpaidOverdueContainer : tokens.paidOnTimeContainer,
            child: Icon(
              isReversed ? Icons.undo_rounded : Icons.payment_rounded,
              size: 18,
              color: isReversed ? tokens.unpaidOverdue : tokens.paidOnTime,
            ),
          ),
          title: Text(
            (c['member_name'] as String?) ?? 'Member',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: isReversed ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            c['received_at'] != null ? c['received_at'].toString().split('T')[0] : '',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Text(
            amount.formatShort(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isReversed ? tokens.onSurfaceVariant : tokens.onSurface,
              decoration: isReversed ? TextDecoration.lineThrough : null,
            ),
          ),
        );
      },
    );
  }
}
