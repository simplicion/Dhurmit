import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/money/app_money.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_widgets.dart';

class CollectionHistoryScreen extends StatefulWidget {
  final String committeeId;

  const CollectionHistoryScreen({super.key, required this.committeeId});

  @override
  State<CollectionHistoryScreen> createState() => _CollectionHistoryScreenState();
}

class _CollectionHistoryScreenState extends State<CollectionHistoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _collections = [];

  @override
  void initState() {
    super.initState();
    _fetchCollections();
  }

  Future<void> _fetchCollections() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = context.read<AuthState>().apiClient;
      final res = await client.get('/committees/${widget.committeeId}/collections');
      if (mounted) {
        setState(() {
          _collections = res is List ? res : [];
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

  Future<void> _reverseCollection(String collectionId) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final tokens = ctx.watch<ThemeProvider>().tokens;
        return AlertDialog(
          title: const Text('Reverse Collection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will reverse the collection and restore previous dues. Ledger history is append-only and this reversal will be logged for audit.',
                style: TextStyle(fontSize: 13, color: tokens.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Reversal *',
                  hintText: 'e.g. Recorded under wrong member by mistake',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.unpaidOverdue,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (reasonController.text.trim().length < 5) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason of at least 5 characters.')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Confirm Reversal'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        final client = context.read<AuthState>().apiClient;
        await client.post(
          '/collections/$collectionId/reverse',
          body: {
            'reason': reasonController.text.trim(),
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Collection reversed successfully.')),
          );
          await _fetchCollections();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error reversing collection: $e')),
          );
        }
      }
    }
  }

  void _showCollectionDetails(Map<String, dynamic> c) {
    final tokens = context.read<ThemeProvider>().tokens;
    final isReversed = c['reversal_status'] == 'REVERSED';
    final amount = AppMoney.fromPaisa(c['amount_minor']);
    final receivedAt = c['received_at'] != null ? c['received_at'].toString().split('T')[0] : 'N/A';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Collection Receipt',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: tokens.onSurface,
                  ),
                ),
                if (isReversed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tokens.unpaidOverdueContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'REVERSED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: tokens.unpaidOverdue,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('Member', (c['member_name'] as String?) ?? 'N/A', tokens),
            _buildDetailRow('Amount', amount.formatShort(), tokens),
            _buildDetailRow('Received Date', receivedAt, tokens),
            _buildDetailRow('Payment Method', (c['payment_method'] as String?) ?? 'Cash', tokens),
            if (c['reference'] != null && c['reference'].toString().isNotEmpty)
              _buildDetailRow('Reference', c['reference'].toString(), tokens),
            if (c['note'] != null && c['note'].toString().isNotEmpty)
              _buildDetailRow('Note', c['note'].toString(), tokens),
            _buildDetailRow('Recorded By', (c['recorded_by_name'] as String?) ?? 'Organizer', tokens),
            _buildDetailRow('Allocations', '${c['allocation_count'] ?? 1} due date(s) covered', tokens),
            if (isReversed && c['reversal_reason'] != null)
              _buildDetailRow('Reversal Reason', c['reversal_reason'].toString(), tokens),
            const SizedBox(height: 24),
            if (!isReversed)
              PrimaryButton(
                label: 'Reverse / Correct this Collection',
                icon: Icons.undo_rounded,
                isOutlined: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _reverseCollection(c['id'] as String);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, AppColorTokens tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: tokens.onSurfaceVariant)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.onSurface)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;

    if (_isLoading) {
      return const LoadingState(message: 'Loading collection register...');
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _fetchCollections);
    }

    if (_collections.isEmpty) {
      return const EmptyStateWidget(
        title: 'No Collections Recorded',
        subtitle: 'Record payments from the committee overview or members tab to populate the register.',
        icon: Icons.receipt_long_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCollections,
      child: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: _collections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final c = _collections[index];
          final amount = AppMoney.fromPaisa(c['amount_minor']);
          final isReversed = c['reversal_status'] == 'REVERSED';
          final receivedAt = c['received_at'] != null ? c['received_at'].toString().split('T')[0] : '';

          return Container(
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.outlineVariant),
            ),
            child: ListTile(
              onTap: () => _showCollectionDetails(c as Map<String, dynamic>),
              leading: CircleAvatar(
                backgroundColor: isReversed ? tokens.unpaidOverdueContainer : tokens.paidOnTimeContainer,
                child: Icon(
                  isReversed ? Icons.undo_rounded : Icons.payments_rounded,
                  size: 20,
                  color: isReversed ? tokens.unpaidOverdue : tokens.paidOnTime,
                ),
              ),
              title: Text(
                (c['member_name'] as String?) ?? 'Member',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: isReversed ? TextDecoration.lineThrough : null,
                  color: isReversed ? tokens.onSurfaceVariant : tokens.onSurface,
                ),
              ),
              subtitle: Text(
                'Received: $receivedAt • ${c['payment_method'] ?? 'Cash'}',
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
                      color: isReversed ? tokens.onSurfaceVariant : tokens.onSurface,
                      decoration: isReversed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (isReversed)
                    Text(
                      'REVERSED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: tokens.unpaidOverdue,
                      ),
                    )
                  else
                    Text(
                      'View >',
                      style: TextStyle(fontSize: 11, color: tokens.primary),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
