import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/money_input_field.dart';

class CreateCommitteeScreen extends StatefulWidget {
  const CreateCommitteeScreen({super.key});

  @override
  State<CreateCommitteeScreen> createState() => _CreateCommitteeScreenState();
}

class _CreateCommitteeScreenState extends State<CreateCommitteeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_amountPaisa <= BigInt.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid contribution amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final client = context.read<AuthState>().apiClient;
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);

      await client.post('/committees', body: {
        'name': _nameController.text.trim(),
        'currencyCode': 'NPR',
        'timezone': 'Asia/Kathmandu',
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
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Committee created successfully')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;

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
                  label: 'Contribution Amount per Member (NPR)',
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
