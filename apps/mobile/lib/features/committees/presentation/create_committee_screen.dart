import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/location/country_model.dart';
import '../../../core/location/country_picker_bottom_sheet.dart';
import '../../../core/location/country_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/money_input_field.dart';
import '../../../core/sync/offline_cache_store.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/sync/sync_outbox_item.dart';

class CreateCommitteeScreen extends StatefulWidget {
  const CreateCommitteeScreen({super.key});

  @override
  State<CreateCommitteeScreen> createState() => _CreateCommitteeScreenState();
}

class _CreateCommitteeScreenState extends State<CreateCommitteeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  CountryProfile? _customCountry;
  DateTime _startDate = DateTime.now();
  int _durationCount = 10;
  final String _durationUnit = 'MONTH';
  String _frequency = 'MONTHLY';
  int _dayOfMonth = 26;
  String _allocationPolicy = 'FIFO';
  bool _allowPartialPayment = false;
  BigInt _amountPaisa = BigInt.zero;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectCountry() async {
    final country = await CountryPickerBottomSheet.show(context);
    if (country != null) {
      setState(() {
        _customCountry = country;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_amountPaisa <= BigInt.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid contribution amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final countryProvider = context.read<CountryProvider>();
    final effectiveCountry = _customCountry ?? countryProvider.activeCountry;
    final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final syncEngine = context.read<SyncEngine>();
    final cacheStore = context.read<OfflineCacheStore>();
    final authState = context.read<AuthState>();
    final wsId = authState.activeWorkspace?['id']?.toString() ?? 'default';

    final committeePayload = {
      'name': _nameController.text.trim(),
      'currencyCode': effectiveCountry.currencyCode,
      'timezone': effectiveCountry.timeZone,
      'startDate': startDateStr,
      'duration': {
        'count': _durationCount,
        'unit': _durationUnit,
      },
      'schedule': {
        'frequency': _frequency,
        'rule': _frequency == 'MONTHLY' ? <String, dynamic>{'dayOfMonth': _dayOfMonth} : <String, dynamic>{},
      },
      'contributionAmountMinor': _amountPaisa.toInt(),
      'allowPartialPayment': _allowPartialPayment,
      'allocationPolicy': _allocationPolicy,
    };

    if (!syncEngine.isOnline) {
      final localId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      final localCommittee = {
        'id': localId,
        ...committeePayload,
        'status': 'DRAFT',
        'isOfflineCreated': true,
        'createdAt': DateTime.now().toIso8601String(),
        'membersCount': 0,
      };

      final cached = cacheStore.getCachedCommittees(wsId);
      cached.insert(0, localCommittee);
      await cacheStore.cacheCommittees(wsId, cached);

      await syncEngine.enqueueMutation(
        mutationType: SyncMutationType.createCommittee,
        endpoint: '/committees',
        payload: committeePayload,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline: Committee saved locally! Will sync when connection is restored.'),
          backgroundColor: Colors.orange,
        ),
      );
      context.pop(true);
      return;
    }

    try {
      final client = authState.apiClient;
      final res = await client.post('/committees', body: committeePayload);
      if (res is Map<String, dynamic>) {
        final cached = cacheStore.getCachedCommittees(wsId);
        cached.insert(0, res);
        await cacheStore.cacheCommittees(wsId, cached);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Committee created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop(true);
    } catch (e) {
      // Network drop fallback: queue offline
      final localId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      final localCommittee = {
        'id': localId,
        ...committeePayload,
        'status': 'DRAFT',
        'isOfflineCreated': true,
        'createdAt': DateTime.now().toIso8601String(),
        'membersCount': 0,
      };

      final cached = cacheStore.getCachedCommittees(wsId);
      cached.insert(0, localCommittee);
      await cacheStore.cacheCommittees(wsId, cached);

      await syncEngine.enqueueMutation(
        mutationType: SyncMutationType.createCommittee,
        endpoint: '/committees',
        payload: committeePayload,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network unreachable: Committee saved locally and queued for sync.'),
          backgroundColor: Colors.orange,
        ),
      );
      context.pop(true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;
    final countryProvider = context.watch<CountryProvider>();
    final effectiveCountry = _customCountry ?? countryProvider.activeCountry;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Committee', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Location & Country Selection Card ───
                InkWell(
                  onTap: _selectCountry,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.surfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Text(effectiveCountry.flag, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${effectiveCountry.name} (${effectiveCountry.currencyCode})',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: tokens.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.edit_location_alt_rounded, size: 14, color: tokens.primary),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Time Zone: ${effectiveCountry.timeZone}',
                                style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _selectCountry,
                          child: const Text('Change', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Committee Name',
                    hintText: 'e.g. Asan Bazzar Committee 2026',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Name must be at least 2 characters' : null,
                ),
                const SizedBox(height: 16),
                MoneyInputField(
                  controller: _amountController,
                  label: 'Contribution Amount per Member (${effectiveCountry.currencyCode})',
                  onChangedPaisa: (paisa) {
                    setState(() {
                      _amountPaisa = paisa;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.calendar_today_rounded, color: tokens.primary),
                    title: const Text('Start Date'),
                    subtitle: Text(DateFormat('yyyy-MM-dd (EEEE)').format(_startDate)),
                    trailing: const Icon(Icons.edit_calendar_rounded),
                    onTap: _pickStartDate,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _frequency,
                        decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                          DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                          DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                        ],
                        onChanged: (v) => setState(() => _frequency = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _durationCount,
                        decoration: InputDecoration(
                          labelText: 'Duration ($_durationUnit)',
                          border: const OutlineInputBorder(),
                        ),
                        items: List.generate(24, (i) => i + 1)
                            .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                            .toList(),
                        onChanged: (v) => setState(() => _durationCount = v!),
                      ),
                    ),
                  ],
                ),
                if (_frequency == 'MONTHLY') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _dayOfMonth,
                    decoration: const InputDecoration(
                      labelText: 'Due Day of Month',
                      helperText: 'Days 29-31 will clamp to the last valid day of shorter months (e.g. Feb 28/29).',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(31, (i) => i + 1)
                        .map((d) => DropdownMenuItem(value: d, child: Text('Day $d of month')))
                        .toList(),
                    onChanged: (v) => setState(() => _dayOfMonth = v!),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _allocationPolicy,
                  decoration: const InputDecoration(
                    labelText: 'Lump-Sum Allocation Policy',
                    helperText: 'FIFO automatically covers the oldest overdue obligations first.',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'FIFO', child: Text('Oldest Due First (FIFO)')),
                    DropdownMenuItem(value: 'MANUAL', child: Text('Manual Allocation Only')),
                  ],
                  onChanged: (v) => setState(() => _allocationPolicy = v!),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Allow Partial Payments'),
                  subtitle: const Text('Allow members to pay less than the full due amount for an obligation'),
                  value: _allowPartialPayment,
                  onChanged: (v) => setState(() => _allowPartialPayment = v),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Create Committee',
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
