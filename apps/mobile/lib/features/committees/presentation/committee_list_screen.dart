import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/money/app_money.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../../core/sync/offline_cache_store.dart';
import 'widgets/join_committee_bottom_sheet.dart';

class CommitteeListScreen extends StatefulWidget {
  const CommitteeListScreen({super.key});

  @override
  State<CommitteeListScreen> createState() => _CommitteeListScreenState();
}

class _CommitteeListScreenState extends State<CommitteeListScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _committees = [];

  @override
  void initState() {
    super.initState();
    _fetchCommittees();
  }

  Future<void> _fetchCommittees() async {
    final authState = context.read<AuthState>();
    final cacheStore = context.read<OfflineCacheStore>();
    final wsId = authState.activeWorkspace?['id']?.toString() ?? 'default';

    // 1. Immediately render cached data if available (zero waiting time)
    final cached = cacheStore.getCachedCommittees(wsId);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _committees = cached;
        _isLoading = false;
        _error = null;
      });
    } else {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }
    }

    // 2. Fetch fresh updates in background if authenticated
    try {
      final client = authState.apiClient;
      if (authState.isAuthenticated && client.authToken != null && client.authToken != 'offline_session_active') {
        final res = await client.get('/committees');
        if (mounted) {
          final list = res is List ? res : <dynamic>[];
          setState(() {
            _committees = list;
            _isLoading = false;
            _error = null;
          });
          await cacheStore.cacheCommittees(wsId, list.cast<Map<String, dynamic>>());
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        if (_committees.isNotEmpty) {
          // Keep showing cached data silently without disrupting user
          setState(() {
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  void _openJoinCommitteeSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => JoinCommitteeBottomSheet(
        onJoined: () {
          _fetchCommittees();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;
    final authState = context.watch<AuthState>();
    final bool isMember = authState.isMember;
    final String workspaceName = (authState.activeWorkspace?['name'] as String?) ?? 'Committees';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/icon.png',
                  height: 28,
                  width: 28,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                isMember ? 'Joined Committees' : workspaceName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_rounded),
            tooltip: 'Join Committee with Code',
            onPressed: _openJoinCommitteeSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchCommittees,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: tokens.primary,
        foregroundColor: tokens.onPrimary,
        icon: Icon(isMember ? Icons.group_add_rounded : Icons.add_rounded),
        label: Text(isMember ? 'Join Committee' : 'New Committee'),
        onPressed: () async {
          if (isMember) {
            _openJoinCommitteeSheet();
          } else {
            final res = await context.push('/committees/create');
            if (res == true) await _fetchCommittees();
          }
        },
      ),
      body: _buildBody(tokens, isMember),
    );
  }

  Widget _buildBody(AppColorTokens tokens, bool isMember) {
    if (_isLoading) {
      return const LoadingStateWidget(message: 'Loading committees...');
    }

    if (_error != null) {
      return ErrorStateWidget(
        message: _error!,
        onRetry: _fetchCommittees,
      );
    }

    if (_committees.isEmpty) {
      return EmptyStateWidget(
        icon: isMember ? Icons.person_search_rounded : Icons.groups_outlined,
        title: isMember ? 'No Committees Joined' : 'No Committees Found',
        description: isMember
            ? 'Enter your 8-digit Committee Code and registered mobile number to view your committee dues and auctions.'
            : 'You have not created any committees in this workspace yet.',
        actionLabel: isMember ? 'Join with Code' : 'Create Committee',
        onAction: () async {
          if (isMember) {
            _openJoinCommitteeSheet();
          } else {
            final res = await context.push('/committees/create');
            if (res == true) await _fetchCommittees();
          }
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCommittees,
      color: tokens.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _committees.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final c = _committees[index];
          final expected = AppMoney.fromPaisa(c['total_expected_minor'] ?? 0);
          final collected = AppMoney.fromPaisa(c['total_collected_minor'] ?? 0);
          final status = c['status'] ?? 'DRAFT';
          final memberCount = c['member_count'] ?? 0;

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                context.push('/committees/${c['id']}');
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            (c['name'] as String?) ?? 'Unnamed Committee',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: tokens.onSurface,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'ACTIVE'
                                ? tokens.paidOnTimeContainer
                                : tokens.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: status == 'ACTIVE'
                                  ? tokens.paidOnTime
                                  : tokens.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${c['frequency']} • ${c['duration_count']} ${c['duration_unit']}S • $memberCount Members',
                      style: TextStyle(fontSize: 13, color: tokens.onSurfaceVariant),
                    ),
                    if (c['code'] != null && c['code'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: c['code'].toString()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Committee Code "${c['code']}" copied to clipboard! Share it with members.'),
                              backgroundColor: tokens.primary,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: tokens.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: tokens.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('CODE: ', style: TextStyle(fontSize: 10, color: tokens.onSurfaceVariant)),
                              Text(
                                c['code'].toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: tokens.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.copy_rounded, size: 12, color: tokens.primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Collected', style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text(
                              collected.formatShort(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: tokens.paidOnTime,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total Expected', style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text(
                              expected.formatShort(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: tokens.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
