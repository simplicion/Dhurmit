import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/sync/sync_engine.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final tokens = themeProvider.tokens;
    final auth = context.watch<AuthState>();
    final user = auth.user;
    final workspace = auth.activeWorkspace;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: const Text('Settings & Preferences'),
        backgroundColor: tokens.surface,
        foregroundColor: tokens.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile & Workspace Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: tokens.primaryContainer,
                      child: Text(
                        (user?['displayName'] as String?)?.isNotEmpty == true
                            ? (user!['displayName'] as String)[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: tokens.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (user?['displayName'] as String?) ?? 'Signed In Organizer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: tokens.onSurface,
                            ),
                          ),
                          Text(
                            (user?['email'] as String?) ?? '',
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
                if (workspace != null) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Workspace',
                        style: TextStyle(fontSize: 13, color: tokens.onSurfaceVariant),
                      ),
                      Text(
                        (workspace['name'] as String?) ?? 'Default Workspace',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: tokens.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Theme Settings Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_rounded, color: tokens.primary),
                    const SizedBox(width: 10),
                    Text(
                      'App Theme',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: tokens.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose between Blue and Red primary themes. Semantic status colors (Green, Orange, Red, Violet) are rigorously preserved across both themes.',
                  style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
                ),
                const SizedBox(height: 16),

                // Theme Selector Options
                Row(
                  children: [
                    Expanded(
                      child: _buildThemeChoiceCard(
                        context: context,
                        mode: AppThemeMode.blue,
                        title: 'Blue Theme',
                        primaryColor: const Color(0xFF1565C0),
                        isSelected: themeProvider.mode == AppThemeMode.blue,
                        tokens: tokens,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildThemeChoiceCard(
                        context: context,
                        mode: AppThemeMode.red,
                        title: 'Red Theme',
                        primaryColor: const Color(0xFFC62828),
                        isSelected: themeProvider.mode == AppThemeMode.red,
                        tokens: tokens,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Semantic Token Swatches
                Text(
                  'Consistent Semantic Status Tokens:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusChip('Paid On Time', tokens.paidOnTime, tokens.paidOnTimeContainer),
                    _buildStatusChip('Paid Late', tokens.paidLate, tokens.paidLateContainer),
                    _buildStatusChip('Overdue', tokens.unpaidOverdue, tokens.unpaidOverdueContainer),
                    _buildStatusChip('Partial', tokens.partiallyPaid, tokens.partiallyPaidContainer),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Offline Sync & Outbox Queue Card
          Consumer<SyncEngine>(
            builder: (context, syncEngine, _) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sync_rounded, color: tokens.primary),
                        const SizedBox(width: 10),
                        Text(
                          'Offline Sync & Storage',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: tokens.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: syncEngine.isOnline ? tokens.paidOnTimeContainer : tokens.paidLateContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            syncEngine.isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: syncEngine.isOnline ? tokens.paidOnTime : tokens.paidLate,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'All records, collections, and statements can be entered offline. When connectivity is restored, queued mutations sync automatically with the PostgreSQL server.',
                      style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Queued Changes: ${syncEngine.pendingCount}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tokens.onSurface,
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.primary,
                            foregroundColor: tokens.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: syncEngine.isOnline && syncEngine.pendingCount > 0 && syncEngine.state != SyncEngineState.syncing
                              ? () => syncEngine.syncNow()
                              : null,
                          icon: syncEngine.state == SyncEngineState.syncing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.sync, size: 16),
                          label: Text(syncEngine.state == SyncEngineState.syncing ? 'Syncing...' : 'Sync Now'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Legal & Boundary Notice Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security_rounded, size: 20, color: tokens.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Legal & Operational Notice',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: tokens.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Software recordkeeping tool for organizers replacing paper notebooks.\n'
                  '• Does NOT provide stored value, escrow, wallet, or payment processing.\n'
                  '• All financial values recorded in integer minor units (NPR paisa).\n'
                  '• PostgreSQL ledger is append-only with full audit trail.\n'
                  '• Subject to Nepal financial recordkeeping and cooperative compliance.',
                  style: TextStyle(fontSize: 12, height: 1.5, color: tokens.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sign Out Button
          PrimaryButton(
            label: 'Sign Out',
            icon: Icons.logout_rounded,
            isOutlined: true,
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await auth.logout();
              }
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 52,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Dhurmit Committee Management v1.0.0',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tokens.onSurface),
                ),
                Text(
                  'Nepal Edition',
                  style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeChoiceCard({
    required BuildContext context,
    required AppThemeMode mode,
    required String title,
    required Color primaryColor,
    required bool isSelected,
    required AppColorTokens tokens,
  }) {
    return InkWell(
      onTap: () {
        context.read<ThemeProvider>().setTheme(mode);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.08) : tokens.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primaryColor : tokens.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(radius: 14, backgroundColor: primaryColor),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? primaryColor : tokens.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: isSelected ? primaryColor : tokens.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
