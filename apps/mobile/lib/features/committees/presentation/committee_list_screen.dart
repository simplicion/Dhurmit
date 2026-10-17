import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/money/app_money.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/state_widgets.dart';

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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = context.read<AuthState>().apiClient;
      final res = await client.get('/committees');
      if (mounted) {
        setState(() {
          _committees = res is List ? res : [];
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
    final String workspaceName = (context.watch<AuthState>().activeWorkspace?['name'] as String?) ?? 'Committees';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          workspaceName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchCommittees,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: tokens.primary,
        foregroundColor: tokens.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Committee'),
        onPressed: () async {
          final res = await context.push('/committees/create');
          if (res == true) await _fetchCommittees();
        },
      ),
      body: _buildBody(tokens),
    );
  }

  Widget _buildBody(AppColorTokens tokens) {
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
        icon: Icons.groups_outlined,
        title: 'No Committees Found',
        description: 'You have not created any committees in this workspace yet.',
        actionLabel: 'Create Committee',
        onAction: () async {
          final res = await context.push('/committees/create');
          if (res == true) await _fetchCommittees();
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
