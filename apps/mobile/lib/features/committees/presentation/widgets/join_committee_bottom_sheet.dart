import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/api/auth_state.dart';
import '../../../../core/money/app_money.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/primary_button.dart';

class JoinCommitteeBottomSheet extends StatefulWidget {
  final VoidCallback onJoined;

  const JoinCommitteeBottomSheet({super.key, required this.onJoined});

  @override
  State<JoinCommitteeBottomSheet> createState() => _JoinCommitteeBottomSheetState();
}

class _JoinCommitteeBottomSheetState extends State<JoinCommitteeBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+977';

  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _joinResult;

  final List<Map<String, String>> _countryCodes = [
    {'name': 'Nepal', 'code': '+977', 'flag': '🇳🇵'},
    {'name': 'India', 'code': '+91', 'flag': '🇮🇳'},
    {'name': 'United States', 'code': '+1', 'flag': '🇺🇸'},
    {'name': 'United Kingdom', 'code': '+44', 'flag': '🇬🇧'},
    {'name': 'UAE', 'code': '+971', 'flag': '🇦🇪'},
    {'name': 'Qatar', 'code': '+974', 'flag': '🇶🇦'},
    {'name': 'Australia', 'code': '+61', 'flag': '🇦🇺'},
  ];

  @override
  void dispose() {
    _codeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = context.read<AuthState>().apiClient;
      final res = await client.post('/committees/join', body: {
        'committeeCode': _codeController.text.trim().toUpperCase(),
        'countryCode': _selectedCountryCode,
        'phoneNumber': _phoneController.text.trim(),
      });

      if (mounted) {
        setState(() {
          _joinResult = res as Map<String, dynamic>;
          _isLoading = false;
        });
        widget.onJoined();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tokens.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_joinResult == null) ...[
                // Title and subtitle
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tokens.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.group_add_rounded, color: tokens.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join Committee',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: tokens.onSurface,
                            ),
                          ),
                          Text(
                            'Enter your 8-digit Committee Code & Phone',
                            style: TextStyle(
                              fontSize: 13,
                              color: tokens.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.unpaidOverdueContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.unpaidOverdue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline_rounded, color: tokens.unpaidOverdue, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(fontSize: 13, color: tokens.unpaidOverdue, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 8-Digit Committee Code Field
                      Text(
                        'Committee Code (8 characters)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.onSurface),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          letterSpacing: 3,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. DH7K9M2P',
                          hintStyle: TextStyle(
                            letterSpacing: 2,
                            color: tokens.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          prefixIcon: Icon(Icons.tag_rounded, color: tokens.primary),
                          filled: true,
                          fillColor: tokens.surfaceVariant.withValues(alpha: 0.35),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the 8-digit committee code';
                          }
                          if (value.trim().length < 6) {
                            return 'Code must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Mobile Phone Number with Country Code
                      Text(
                        'Your Mobile Number (Unique Finder)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.onSurface),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: tokens.surfaceVariant.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: tokens.outlineVariant),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCountryCode,
                                items: _countryCodes.map((c) {
                                  return DropdownMenuItem<String>(
                                    value: c['code'],
                                    child: Text(
                                      '${c['flag']} ${c['code']}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCountryCode = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: '9801234567',
                                prefixIcon: Icon(Icons.phone_rounded, color: tokens.primary),
                                filled: true,
                                fillColor: tokens.surfaceVariant.withValues(alpha: 0.35),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your mobile phone number';
                                }
                                if (value.trim().length < 6) {
                                  return 'Phone number too short';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your mobile number must match the one entered by the organizer when setting up the committee.',
                        style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),

                      PrimaryButton(
                        label: 'Search & Join Committee',
                        icon: Icons.check_circle_outline_rounded,
                        isLoading: _isLoading,
                        onPressed: _handleJoin,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Success View showing committee and member dues
                _buildSuccessView(tokens),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(AppColorTokens tokens) {
    final committee = _joinResult!['committee'] as Map<String, dynamic>;
    final member = _joinResult!['member'] as Map<String, dynamic>;
    final duesSummary = _joinResult!['duesSummary'] as Map<String, dynamic>;
    final obligations = (_joinResult!['obligations'] as List?) ?? [];

    final totalDue = AppMoney.fromPaisa(duesSummary['totalDueMinor'] ?? 0);
    final totalPaid = AppMoney.fromPaisa(duesSummary['totalAllocatedMinor'] ?? 0);
    final outstanding = AppMoney.fromPaisa(duesSummary['totalOutstandingMinor'] ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.paidOnTimeContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: tokens.paidOnTime, size: 36),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Successfully Joined!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: tokens.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'You are registered as "${member['displayName']}" in ${committee['name']}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: tokens.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),

        // Financial Summary Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.outlineVariant),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Total Dues', style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(
                        totalDue.format(),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.onSurface),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Paid', style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(
                        totalPaid.format(),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.paidOnTime),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Remaining Balance', style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(
                        outstanding.format(),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.unpaidOverdue),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Obligations list preview
        if (obligations.isNotEmpty) ...[
          Text(
            'Payment Schedule & Dues (${obligations.length} installments)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.onSurface),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: obligations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final ob = obligations[idx];
                final isPaid = ob['isPaid'] == true;
                final dueAmount = AppMoney.fromPaisa(ob['dueAmountMinor']);

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: isPaid ? tokens.paidOnTimeContainer : tokens.surfaceVariant,
                    child: Icon(
                      isPaid ? Icons.check_rounded : Icons.schedule_rounded,
                      size: 16,
                      color: isPaid ? tokens.paidOnTime : tokens.onSurfaceVariant,
                    ),
                  ),
                  title: Text(
                    'Installment #${idx + 1} — Due ${ob['dueDate']}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  trailing: Text(
                    dueAmount.formatShort(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPaid ? tokens.paidOnTime : tokens.onSurface,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        PrimaryButton(
          label: 'Go to Committee Dashboard',
          icon: Icons.arrow_forward_rounded,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
