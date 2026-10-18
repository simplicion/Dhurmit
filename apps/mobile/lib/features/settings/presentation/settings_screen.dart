import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/theme/app_color_tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/sync/sync_engine.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSigningOut = false;

  Future<void> _handleSignOut(AuthState auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Sign Out'),
          ],
        ),
        content: const Text('Are you sure you want to sign out of Dhurmit? You will need to log in again to access your committees.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isSigningOut = true);
      try {
        await auth.logout();
        if (mounted) {
          context.go('/login');
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isSigningOut = false);
          context.go('/login');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final tokens = themeProvider.tokens;
    final auth = context.watch<AuthState>();
    final user = auth.user;
    final workspace = auth.activeWorkspace;

    // Completely fail-safe extraction of profile values using .toString()
    String displayName = 'Signed In User';
    if (user != null) {
      final nameVal = user['displayName'] ?? user['display_name'] ?? user['name'] ?? user['email'];
      if (nameVal != null) {
        if (nameVal is String && nameVal.trim().isNotEmpty) {
          displayName = nameVal.trim();
        } else if (nameVal is Map) {
          final first = nameVal['first']?.toString() ?? nameVal['firstName']?.toString() ?? '';
          final last = nameVal['last']?.toString() ?? nameVal['lastName']?.toString() ?? '';
          final combined = '$first $last'.trim();
          if (combined.isNotEmpty) displayName = combined;
        } else {
          displayName = nameVal.toString().trim();
        }
      }
    }

    final String initialLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final String email = user?['email']?.toString() ?? '';
    final String phone = (user?['phone'] ?? user?['phoneNumber'] ?? user?['phone_e164'])?.toString() ?? '';
    final bool isOrganizer = auth.isOrganizer;
    final String workspaceName = workspace?['name']?.toString() ?? 'Default Workspace';
    final String workspaceRole = workspace?['role']?.toString() ?? (isOrganizer ? 'OWNER' : 'VIEWER');

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        title: const Text('Settings & Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: tokens.surface,
        foregroundColor: tokens.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            tooltip: 'Sign Out',
            onPressed: _isSigningOut ? null : () => _handleSignOut(auth),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── 1. USER PROFILE CARD ───
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              tokens.primary,
                              tokens.secondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tokens.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initialLetter,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: tokens.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isOrganizer
                                        ? tokens.primary.withValues(alpha: 0.12)
                                        : tokens.secondary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isOrganizer ? '👑 Organizer' : '👥 Member',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isOrganizer ? tokens.primary : tokens.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.phone_rounded, size: 14, color: tokens.onSurfaceVariant),
                                  const SizedBox(width: 5),
                                  Text(
                                    phone,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: tokens.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.email_outlined, size: 14, color: tokens.onSurfaceVariant),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      email,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: tokens.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  // Workspace Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.business_center_rounded, size: 16, color: tokens.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            'Active Workspace',
                            style: TextStyle(fontSize: 13, color: tokens.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            workspaceName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: tokens.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: tokens.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: tokens.outlineVariant),
                            ),
                            child: Text(
                              workspaceRole,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: tokens.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── 2. THEME & APPEARANCE CARD ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(16),
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
                    'Choose between Classic Blue and Bold Red themes. Financial status colors are preserved across both palettes.',
                    style: TextStyle(fontSize: 12, color: tokens.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),

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
                  const SizedBox(height: 14),

                  Text(
                    'Financial Status Legend:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tokens.onSurface),
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
            const SizedBox(height: 16),

            // ─── 3. OFFLINE SYNC & STORAGE CARD ───
            Consumer<SyncEngine>(
              builder: (context, syncEngine, _) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(16),
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
                      const SizedBox(height: 8),
                      Text(
                        'All collections, records, and bids are saved offline instantly. They automatically synchronize to the server when connected.',
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
            const SizedBox(height: 16),

            // ─── 4. LEGAL & BOUNDARY NOTICE ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
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
                    '• Dhurmit is a financial recordkeeping and administration software tool.\n'
                    '• Does NOT act as escrow, wallet, banking entity, or payment gateway.\n'
                    '• All integer minor ledger units represent NPR paisa.\n'
                    '• PostgreSQL audit ledgers are cryptographically verifiable and append-only.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: tokens.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── 5. PROMINENT LOGOUT / SIGN OUT BUTTON ───
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700,
                elevation: 0,
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSigningOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                    )
                  : const Icon(Icons.logout_rounded, size: 20, color: Colors.red),
              label: Text(
                _isSigningOut ? 'Signing Out...' : 'Sign Out of Dhurmit',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              onPressed: _isSigningOut ? null : () => _handleSignOut(auth),
            ),
            const SizedBox(height: 20),

            // ─── 6. APP BRANDING FOOTER ───
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
                  const SizedBox(height: 8),
                  Text(
                    'DHURMIT COMMITTEE MANAGEMENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: tokens.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'v1.0.0 • Nepal Edition • 180 Sovereign Cloud',
                    style: TextStyle(fontSize: 11, color: tokens.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
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
