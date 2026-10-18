import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/money/app_money.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/money_input_field.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_outbox_item.dart';
import '../../../core/sync/offline_cache_store.dart';

class RecordCollectionBottomSheet extends StatefulWidget {
  final String committeeId;
  final String? initialMemberId;
  final VoidCallback onSuccess;

  const RecordCollectionBottomSheet({
    super.key,
    required this.committeeId,
    this.initialMemberId,
    required this.onSuccess,
  });

  @override
  State<RecordCollectionBottomSheet> createState() => _RecordCollectionBottomSheetState();
}

class _RecordCollectionBottomSheetState extends State<RecordCollectionBottomSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _referenceController = TextEditingController();

  DateTime _receivedDate = DateTime.now();
  String? _selectedMemberId;
  BigInt _amountPaisa = BigInt.zero;
  String _methodLabel = 'CASH';
  bool _isLoadingMembers = true;
  bool _isSubmitting = false;
  List<dynamic> _members = [];
  List<dynamic> _memberObligations = [];
  bool _isLoadingObligations = false;

  // Stable idempotency key for this recording session
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.initialMemberId;
    _idempotencyKey = 'idem_${DateTime.now().millisecondsSinceEpoch}_${widget.committeeId.substring(0, 8)}';
    _fetchMembers();
    if (widget.initialMemberId != null) {
      _fetchMemberStatement(widget.initialMemberId!);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    try {
      final cacheStore = context.read<OfflineCacheStore>();
      final cached = cacheStore.getCachedMembers(widget.committeeId);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _members = cached;
          _isLoadingMembers = false;
        });
      }

      final client = context.read<AuthState>().apiClient;
      final res = await client.get('/committees/${widget.committeeId}/members?status=ACTIVE');
      if (mounted) {
        final list = res is List ? res : <dynamic>[];
        setState(() {
          _members = list;
          _isLoadingMembers = false;
        });
        await cacheStore.cacheMembers(widget.committeeId, list.cast<Map<String, dynamic>>());
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _fetchMemberStatement(String memberId) async {
    setState(() => _isLoadingObligations = true);
    try {
      final client = context.read<AuthState>().apiClient;
      final res = await client.get('/committees/${widget.committeeId}/members/$memberId/statement');
      if (mounted) {
        final statement = res['statement'] as Map<String, dynamic>?;
        final obs = statement?['obligations'] as List? ?? [];
        setState(() {
          _memberObligations = obs;
          _isLoadingObligations = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingObligations = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receivedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _receivedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_selectedMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a member')),
      );
      return;
    }

    if (_amountPaisa <= BigInt.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount greater than zero')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final syncEngine = context.read<SyncEngine>();
    final receivedAtIso = _receivedDate.toUtc().toIso8601String();

    final payload = {
      'memberId': _selectedMemberId,
      'amountMinor': _amountPaisa.toInt(),
      'currencyCode': 'NPR',
      'receivedAt': receivedAtIso,
      'methodLabel': _methodLabel,
      'reference': _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
      'note': _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    };

    if (!syncEngine.isOnline) {
      await syncEngine.enqueueMutation(
        mutationType: SyncMutationType.recordCollection,
        endpoint: '/committees/${widget.committeeId}/collections',
        payload: payload,
        customIdempotencyKey: _idempotencyKey,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline: Collection recorded & queued for automatic sync!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final client = context.read<AuthState>().apiClient;
      await client.post(
        '/committees/${widget.committeeId}/collections',
        idempotencyKey: _idempotencyKey,
        body: payload,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Collection recorded and allocated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Network interruption fallback: queue offline
      await syncEngine.enqueueMutation(
        mutationType: SyncMutationType.recordCollection,
        endpoint: '/committees/${widget.committeeId}/collections',
        payload: payload,
        customIdempotencyKey: _idempotencyKey,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network dropped: Saved offline and queued for automatic sync.'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Record Collection',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: tokens.onSurface,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Member selector
            if (_isLoadingMembers)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedMemberId,
                decoration: const InputDecoration(
                  labelText: 'Select Member',
                  prefixIcon: Icon(Icons.person_search_rounded),
                  border: OutlineInputBorder(),
                ),
                items: _members.map<DropdownMenuItem<String>>((dynamic m) {
                  final map = m as Map<String, dynamic>;
                  final outstanding = AppMoney.fromPaisa(map['totalOutstandingMinor'] ?? 0);
                  return DropdownMenuItem<String>(
                    value: map['id'] as String,
                    child: Text('${map['displayName']} (Dues: ${outstanding.formatShort()})'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedMemberId = val);
                  if (val != null) _fetchMemberStatement(val);
                },
              ),
            const SizedBox(height: 16),
            // Amount
            MoneyInputField(
              controller: _amountController,
              label: 'Amount Collected (NPR)',
              onChangedPaisa: (paisa) {
                setState(() => _amountPaisa = paisa);
              },
            ),
            const SizedBox(height: 16),
            // Actual Received Date
            Card(
              child: ListTile(
                leading: Icon(Icons.calendar_today_rounded, color: tokens.primary),
                title: const Text('Actual Received Date'),
                subtitle: Text(DateFormat('yyyy-MM-dd (EEEE)').format(_receivedDate)),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 16),
            // Method Label
            DropdownButtonFormField<String>(
              initialValue: _methodLabel,
              decoration: const InputDecoration(
                labelText: 'Payment Method Label',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('Cash in Hand')),
                DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Manual Bank Transfer Record')),
                DropdownMenuItem(value: 'OTHER', child: Text('Other Manual Record')),
              ],
              onChanged: (val) => setState(() => _methodLabel = val!),
            ),
            const SizedBox(height: 16),
            // Optional Reference and Note
            TextFormField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: 'Reference / Voucher No. (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            // Allocation Preview Box
            _buildAllocationPreview(tokens),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Confirm & Save Collection',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationPreview(AppColorTokens tokens) {
    if (_selectedMemberId == null) return const SizedBox.shrink();

    if (_isLoadingObligations) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(8.0),
        child: CircularProgressIndicator(),
      ));
    }

    final openObligations = _memberObligations.where((o) {
      final out = BigInt.tryParse(o['outstandingAmountMinor'].toString()) ?? BigInt.zero;
      return out > BigInt.zero;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: tokens.primary),
              const SizedBox(width: 6),
              Text(
                'Allocation Preview (Oldest Due First)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: tokens.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (openObligations.isEmpty)
            Text(
              'Member has no open dues.',
              style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
            )
          else ...[
            Text(
              'This collection will automatically settle the oldest open obligations:',
              style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            ...openObligations.take(4).map((ob) {
              final dueStr = ob['dueDate'];
              final out = AppMoney.fromPaisa(ob['outstandingAmountMinor']);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Due: $dueStr', style: const TextStyle(fontSize: 12)),
                    Text('Owing: ${out.formatShort()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
