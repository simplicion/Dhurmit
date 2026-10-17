import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/money/app_money.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/state_widgets.dart';

class MemberListScreen extends StatefulWidget {
  final String committeeId;
  final bool isDraft;
  final VoidCallback onMemberAdded;

  const MemberListScreen({
    super.key,
    required this.committeeId,
    required this.isDraft,
    required this.onMemberAdded,
  });

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _members = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers([String query = '']) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = context.read<AuthState>().apiClient;
      final q = query.trim().isNotEmpty ? '?search=${Uri.encodeComponent(query.trim())}' : '';
      final res = await client.get('/committees/${widget.committeeId}/members$q');
      if (mounted) {
        setState(() {
          _members = res is List ? res : [];
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

  void _showAddMemberDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member to Committee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Member Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.length < 2) return;

              Navigator.pop(ctx);
              try {
                final client = context.read<AuthState>().apiClient;
                await client.post('/committees/${widget.committeeId}/members', body: {
                  'displayName': name,
                  'phone': phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                });
                await _fetchMembers();
                widget.onMemberAdded();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Add Member'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: tokens.primary,
        foregroundColor: tokens.onPrimary,
        onPressed: _showAddMemberDialog,
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search members by name or phone...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _fetchMembers();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onChanged: (val) => _fetchMembers(val),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const LoadingStateWidget(message: 'Loading members...')
                : _error != null
                    ? ErrorStateWidget(message: _error!, onRetry: () => _fetchMembers())
                    : _members.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.person_outline_rounded,
                            title: 'No Members Enrolled',
                            description: 'Add members to start tracking their contribution schedule.',
                            actionLabel: 'Add Member',
                            onAction: _showAddMemberDialog,
                          )
                        : RefreshIndicator(
                            onRefresh: () => _fetchMembers(),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _members.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final m = _members[index];
                                final outstanding = AppMoney.fromPaisa(m['totalOutstandingMinor']);
                                final isOverdue = (BigInt.tryParse(m['totalOutstandingMinor'].toString()) ?? BigInt.zero) > BigInt.zero;

                                final name = (m['displayName'] as String?) ?? 'Member';
                                final phone = m['phone'] as String?;

                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: tokens.primaryContainer,
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: tokens.primary,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      phone != null && phone.isNotEmpty
                                          ? phone
                                          : 'Enrolled: ${m['joinedAt'] ?? ''}',
                                      style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Dues: ${outstanding.formatShort()}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isOverdue ? tokens.unpaidOverdue : tokens.paidOnTime,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text('View Statement >', style: TextStyle(fontSize: 10, color: tokens.primary)),
                                      ],
                                    ),
                                    onTap: () {
                                      context.push('/committees/${widget.committeeId}/members/${m['id']}/statement');
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
