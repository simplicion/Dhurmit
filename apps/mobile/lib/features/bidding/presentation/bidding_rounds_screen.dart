import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/money/app_money.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/state_widgets.dart';

class BiddingRoundsScreen extends StatefulWidget {
  final String committeeId;
  final bool isOrganizer;

  const BiddingRoundsScreen({
    super.key,
    required this.committeeId,
    required this.isOrganizer,
  });

  @override
  State<BiddingRoundsScreen> createState() => _BiddingRoundsScreenState();
}

class _BiddingRoundsScreenState extends State<BiddingRoundsScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _rounds = [];

  @override
  void initState() {
    super.initState();
    _fetchRounds();
  }

  Future<void> _fetchRounds() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = context.read<AuthState>().apiClient;
      final res = await client.get('/committees/${widget.committeeId}/bidding-rounds');
      if (mounted) {
        setState(() {
          _rounds = res is List ? res : [];
          _isLoading = false;
        });
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

  void _openReleaseRoundDialog() {
    final nextRoundNumber = _rounds.length + 1;
    final totalPotController = TextEditingController(text: '500000');
    final minBidController = TextEditingController(text: '5000');
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final tokens = ctx.watch<ThemeProvider>().tokens;
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text('📢', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Release Bidding Round #$nextRoundNumber',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Notify members and open committee pot for bidding',
                                style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Total Pot Amount
                    Text(
                      'Total Pot Amount (NPR)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.onSurface),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: totalPotController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: 'Rs. ',
                        hintText: '500000',
                        filled: true,
                        fillColor: tokens.surfaceVariant.withValues(alpha: 0.35),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Minimum Bid Margin
                    Text(
                      'Minimum Margin / Discount Bid (NPR)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.onSurface),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: minBidController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: 'Rs. ',
                        hintText: '5000',
                        filled: true,
                        fillColor: tokens.surfaceVariant.withValues(alpha: 0.35),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Round Date Picker
                    Text(
                      'Round Date / Opening Date',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.onSurface),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: tokens.surfaceVariant.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: tokens.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: tokens.primary, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down_rounded),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    Text(
                      'Notes or Guidelines (Optional)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.onSurface),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Month 2 Bidding round against 5 Lakh pot',
                        filled: true,
                        fillColor: tokens.surfaceVariant.withValues(alpha: 0.35),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    PrimaryButton(
                      label: 'Release Round & Open Bidding',
                      icon: Icons.check_circle_rounded,
                      onPressed: () async {
                        final potAmount = double.tryParse(totalPotController.text) ?? 500000;
                        final minBid = double.tryParse(minBidController.text) ?? 0;
                        final roundDateStr =
                            '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

                        try {
                          final client = context.read<AuthState>().apiClient;
                          await client.post('/committees/${widget.committeeId}/bidding-rounds', body: {
                            'roundNumber': nextRoundNumber,
                            'roundDate': roundDateStr,
                            'totalPotMinor': (potAmount * 100).toInt(),
                            'minBidMinor': (minBid * 100).toInt(),
                            'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          });
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Bidding Round #$nextRoundNumber released successfully!'),
                              backgroundColor: tokens.paidOnTime,
                            ),
                          );
                          await _fetchRounds();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: tokens.unpaidOverdue),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openPlaceBidDialog(Map<String, dynamic> round) {
    final bidController = TextEditingController();
    final totalPotMinor = BigInt.tryParse(round['totalPotMinor']?.toString() ?? '0') ?? BigInt.zero;
    final totalPot = AppMoney.fromPaisa(totalPotMinor);
    final minBidMinor = BigInt.tryParse(round['minBidMinor']?.toString() ?? '0') ?? BigInt.zero;
    final minBid = AppMoney.fromPaisa(minBidMinor);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final tokens = ctx.watch<ThemeProvider>().tokens;
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        return StatefulBuilder(
          builder: (context, setModalState) {
            double enteredBid = double.tryParse(bidController.text) ?? 0;
            double calculatedPayout = totalPot.toRupees() - enteredBid;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text('💰', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Place Bid for Round #${round['roundNumber']}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Total Monthly Pot: ${totalPot.format()}',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tokens.primary.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        '💡 How it works: In a committee auction, you bid the discount margin you are willing to forgo to take the cash pot this month. The highest margin wins the pot!',
                        style: TextStyle(fontSize: 12, height: 1.4, color: tokens.onBackground),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Your Discount Margin Bid (NPR)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.onSurface),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: bidController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        prefixText: 'Rs. ',
                        hintText: minBid.isPositive ? '${minBid.toRupees()}' : 'e.g. 35000',
                        filled: true,
                        fillColor: tokens.surfaceVariant.withValues(alpha: 0.35),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Live calculation card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tokens.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tokens.outlineVariant),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Your Margin', style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant)),
                              const SizedBox(height: 2),
                              Text(
                                'Rs. ${enteredBid.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.unpaidOverdue),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Net Payout to You', style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant)),
                              const SizedBox(height: 2),
                              Text(
                                calculatedPayout > 0 ? 'Rs. ${calculatedPayout.toStringAsFixed(0)}' : 'Rs. 0',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.paidOnTime),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    PrimaryButton(
                      label: 'Submit Bid (Rs. ${enteredBid.toStringAsFixed(0)})',
                      icon: Icons.gavel_rounded,
                      onPressed: () async {
                        if (enteredBid <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid bid margin')),
                          );
                          return;
                        }

                        try {
                          final client = context.read<AuthState>().apiClient;
                          await client.post('/bidding-rounds/${round['id']}/bids', body: {
                            'bidAmountMinor': (enteredBid * 100).toInt(),
                          });
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Bid of Rs. ${enteredBid.toStringAsFixed(0)} submitted successfully!'),
                              backgroundColor: tokens.paidOnTime,
                            ),
                          );
                          await _fetchRounds();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: tokens.unpaidOverdue),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _awardWinner(Map<String, dynamic> round, Map<String, dynamic> bid) async {
    final tokens = context.read<ThemeProvider>().tokens;
    final winningBidMinor = BigInt.tryParse(bid['bid_amount_minor']?.toString() ?? '0') ?? BigInt.zero;
    final winningBid = AppMoney.fromPaisa(winningBidMinor);
    final totalPotMinor = BigInt.tryParse(round['totalPotMinor']?.toString() ?? '0') ?? BigInt.zero;
    final totalPot = AppMoney.fromPaisa(totalPotMinor);
    final netPayout = totalPot - winningBid;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Text('🏆', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Award Pot Winner'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to award this round pot to:'),
            const SizedBox(height: 8),
            Text(
              '${bid['member_name']}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.paidOnTimeContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Pot:'),
                      Text(totalPot.format(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Winning Discount:'),
                      Text('- ${winningBid.format()}', style: TextStyle(fontWeight: FontWeight.bold, color: tokens.unpaidOverdue)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Net Cash Payout:'),
                      Text(netPayout.format(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: tokens.paidOnTime)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: tokens.paidOnTime, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Award'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final client = context.read<AuthState>().apiClient;
      await client.post('/bidding-rounds/${round['id']}/award', body: {
        'winnerMemberId': bid['member_id'],
        'winningBidMinor': winningBidMinor.toString(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🏆 Pot awarded to ${bid['member_name']} successfully!'),
          backgroundColor: tokens.paidOnTime,
        ),
      );
      await _fetchRounds();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: tokens.unpaidOverdue),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.watch<ThemeProvider>().tokens;

    if (_isLoading) {
      return const LoadingStateWidget(message: 'Loading auction rounds...');
    }

    if (_error != null) {
      return ErrorStateWidget(message: _error!, onRetry: _fetchRounds);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchRounds,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tokens.primary.withValues(alpha: 0.12),
                      tokens.secondary.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tokens.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Text('🎲', style: TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chit Fund Auction & Bids',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: tokens.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.isOrganizer
                                ? 'Release monthly rounds, review member bids, and award payouts.'
                                : 'Participate in monthly bidding to take the cash pot early.',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Organizer Release Round Button
              if (widget.isOrganizer) ...[
                PrimaryButton(
                  label: 'Release New Bidding Round',
                  icon: Icons.campaign_rounded,
                  onPressed: _openReleaseRoundDialog,
                ),
                const SizedBox(height: 20),
              ],

              // Rounds List
              if (_rounds.isEmpty) ...[
                EmptyStateWidget(
                  title: 'No Bidding Rounds Yet',
                  subtitle: widget.isOrganizer
                      ? 'Click "Release New Bidding Round" above to open the pot for members to bid.'
                      : 'The organizer has not released any bidding rounds yet for this committee.',
                  icon: Icons.gavel_rounded,
                ),
              ] else ...[
                Text(
                  'Bidding Rounds (${_rounds.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: tokens.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ..._rounds.map((round) => _buildRoundCard(round as Map<String, dynamic>, tokens)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundCard(Map<String, dynamic> round, AppColorTokens tokens) {
    final status = round['status']?.toString() ?? 'OPEN';
    final isOpen = status == 'OPEN';
    final isAwarded = status == 'AWARDED';

    final totalPotMinor = BigInt.tryParse(round['totalPotMinor']?.toString() ?? '0') ?? BigInt.zero;
    final totalPot = AppMoney.fromPaisa(totalPotMinor);

    final winningBidMinor = BigInt.tryParse(round['winningBidMinor']?.toString() ?? '0') ?? BigInt.zero;
    final winningBid = AppMoney.fromPaisa(winningBidMinor);

    final netPayoutMinor = BigInt.tryParse(round['netPayoutMinor']?.toString() ?? '0') ?? BigInt.zero;
    final netPayout = AppMoney.fromPaisa(netPayoutMinor);

    final bids = (round['bids'] as List?) ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOpen
              ? tokens.paidOnTime.withValues(alpha: 0.5)
              : (isAwarded ? Colors.amber.shade400 : tokens.outlineVariant),
          width: isOpen || isAwarded ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Round Header: Number + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Round #${round['roundNumber']}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? tokens.paidOnTimeContainer
                            : (isAwarded ? Colors.amber.shade100 : tokens.surfaceVariant),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isOpen ? '🟢 LIVE OPEN' : (isAwarded ? '🏆 AWARDED' : status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOpen
                              ? tokens.paidOnTime
                              : (isAwarded ? Colors.brown.shade800 : tokens.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Date: ${round['roundDate']}',
                  style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Financial Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.surfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Pot', style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(
                        totalPot.format(),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.primary),
                      ),
                    ],
                  ),
                  if (isAwarded) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Net Payout Awarded', style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          netPayout.format(),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tokens.paidOnTime),
                        ),
                      ],
                    ),
                  ] else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Bids Received', style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          '${bids.length} Active Bids',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: tokens.onSurface),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Winner Box if Awarded
            if (isAwarded) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Won by ${round['winnerName'] ?? 'Community Member'}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Discount Margin: ${winningBid.format()} • Payout: ${netPayout.format()}',
                            style: TextStyle(fontSize: 12, color: Colors.brown.shade800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // If Open, show Place Bid button for Members
            if (isOpen) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.primary,
                  foregroundColor: tokens.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.gavel_rounded, size: 20),
                label: const Text('Place Your Bid / Bet', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _openPlaceBidDialog(round),
              ),
            ],

            // Live Bids Table / Ranking
            if (bids.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Live Bids Ranking',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tokens.onSurface),
                  ),
                  Text(
                    'Highest Margin First',
                    style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...bids.asMap().entries.map((entry) {
                final idx = entry.key;
                final bid = entry.value as Map<String, dynamic>;
                final bidAmountMinor = BigInt.tryParse(bid['bid_amount_minor']?.toString() ?? '0') ?? BigInt.zero;
                final bidAmount = AppMoney.fromPaisa(bidAmountMinor);
                final memberPayout = totalPot - bidAmount;

                return Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: idx == 0 && isOpen
                        ? tokens.paidOnTimeContainer.withValues(alpha: 0.3)
                        : tokens.surfaceVariant.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: idx == 0 && isOpen ? tokens.paidOnTime.withValues(alpha: 0.3) : tokens.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: idx == 0 ? Colors.amber.shade300 : tokens.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bid['member_name']?.toString() ?? 'Member',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Payout: ${memberPayout.formatShort()}',
                              style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Margin: ${bidAmount.formatShort()}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: tokens.unpaidOverdue,
                            ),
                          ),
                          if (widget.isOrganizer && isOpen) ...[
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _awardWinner(round, bid),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tokens.paidOnTime,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Award Winner',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
