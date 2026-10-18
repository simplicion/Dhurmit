import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/one_eighty_auth_button.dart';
import '../../../core/widgets/one_eighty_launcher.dart';

/// Primary Splash Screen for Dhurmit.
/// Clean, minimalist, and focused:
/// - Official Dhurmit branding logo
/// - Two-line concise description of what the app actually does
/// - Official 180 Identity SSO Button opening 180 Identity bottom sheet directly
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String _selectedRole = 'ORGANIZER'; // 'ORGANIZER' | 'MEMBER'

  final _memberCodeController = TextEditingController();
  final _memberPhoneController = TextEditingController();
  final _memberPasswordController = TextEditingController();
  bool _obscureMemberPassword = true;
  bool _isMemberLoggingIn = false;

  @override
  void dispose() {
    _memberCodeController.dispose();
    _memberPhoneController.dispose();
    _memberPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleMemberLogin() async {
    final code = _memberCodeController.text.trim().toUpperCase();
    final phone = _memberPhoneController.text.trim();
    final password = _memberPasswordController.text.trim();

    if (code.isEmpty || phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Committee Code, Mobile Phone, and Password')),
      );
      return;
    }

    setState(() => _isMemberLoggingIn = true);
    try {
      final authState = context.read<AuthState>();
      await authState.loginWithMemberCredentials(
        committeeCode: code,
        phone: phone,
        password: password,
      );
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMemberLoggingIn = false);
    }
  }

  Future<void> _handle180SignIn() async {
    setState(() => _isLoading = true);
    try {
      const clientId = '180_client_3b759b500c4b8a04f888ec3d91a82bd3';
      final origin = Uri.base.origin.contains('http')
          ? Uri.base.origin
          : 'http://localhost:3000';
      final redirectUri = '$origin/auth/callback';

      // 1. Launch 180 SDK native bottom sheet modal on Web
      final authResultJson = await trigger180WebBottomSheet(clientId, redirectUri);
      if (!mounted) return;

      if (authResultJson != null && authResultJson.isNotEmpty) {
        final authState = context.read<AuthState>();
        String? authCode;
        Map<String, dynamic>? userPayload;

        try {
          final data = jsonDecode(authResultJson) as Map<String, dynamic>;
          if (data['cancelled'] == true) {
            // User intentionally closed the bottom sheet modal
            return;
          }
          authCode = (data['code'] ?? data['token'] ?? data['accessToken'] ?? data['authToken'])?.toString();
          if (data['user'] is Map<String, dynamic>) {
            userPayload = data['user'] as Map<String, dynamic>;
          }
        } catch (_) {
          authCode = authResultJson;
        }

        if ((authCode != null && authCode.isNotEmpty) || userPayload != null) {
          await authState.loginWith180(
            authCode ?? '180_session_verified',
            user: userPayload,
            redirectUri: redirectUri,
            userType: _selectedRole,
          );
          if (mounted) {
            context.go('/home');
          }
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete 180 Identity sign-in: $e'),
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
      backgroundColor: tokens.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── HERO BRANDING & LOGO ───
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 130,
                          width: 130,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── TITLE & SUBTITLE ───
                  Text(
                    'DHURMIT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                      color: tokens.onBackground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'COMMITTEE MANAGEMENT & FINANCIAL LEDGER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: tokens.primary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── TWO LINES MENTIONING WHAT THE APP ACTUALLY DOES ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Automated committee ledgers and contribution tracking for rotating savings groups.\nRecord collections, track member dues, and calculate payouts with 100% offline-first reliability.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: tokens.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ─── ROLE SELECTOR: ORGANIZER VS COMMUNITY MEMBER ───
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: tokens.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: tokens.outline.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _selectedRole = 'ORGANIZER'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedRole == 'ORGANIZER'
                                    ? tokens.surface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _selectedRole == 'ORGANIZER'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '👑',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Organizer',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _selectedRole == 'ORGANIZER'
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: _selectedRole == 'ORGANIZER'
                                          ? tokens.onBackground
                                          : tokens.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _selectedRole = 'MEMBER'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedRole == 'MEMBER'
                                    ? tokens.surface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _selectedRole == 'MEMBER'
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '👥',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Member',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: _selectedRole == 'MEMBER'
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: _selectedRole == 'MEMBER'
                                          ? tokens.onBackground
                                          : tokens.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Micro context banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedRole == 'ORGANIZER'
                          ? tokens.primary.withValues(alpha: 0.07)
                          : tokens.secondary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedRole == 'ORGANIZER'
                            ? tokens.primary.withValues(alpha: 0.2)
                            : tokens.secondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      _selectedRole == 'ORGANIZER'
                          ? '👑 Organizer Mode: Create and run committees, record collections, release monthly bidding rounds & award payouts.'
                          : '👥 Member Mode: Join committees via 8-digit code, view your payment obligations & place bets in auctions.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: tokens.onBackground,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_selectedRole == 'MEMBER') ...[
                    // ─── MEMBER DIRECT LOGIN WITH CODE, PHONE & PASSWORD ───
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: tokens.outline.withValues(alpha: 0.15)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: tokens.secondary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.pin_outlined, color: tokens.secondary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Member Credentials',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: tokens.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _memberCodeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Committee Code / ID *',
                              hintText: 'e.g. DH7K9M2P',
                              prefixIcon: Icon(Icons.tag_rounded),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _memberPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Your Mobile Phone *',
                              hintText: 'e.g. 9801234567',
                              prefixIcon: Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _memberPasswordController,
                            obscureText: _obscureMemberPassword,
                            decoration: InputDecoration(
                              labelText: 'Member Password / PIN *',
                              hintText: 'Assigned by committee manager',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureMemberPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureMemberPassword = !_obscureMemberPassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tokens.primary,
                              foregroundColor: tokens.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isMemberLoggingIn ? null : _handleMemberLogin,
                            child: _isMemberLoggingIn
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login_rounded, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Sign In to Committee',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: tokens.outline.withValues(alpha: 0.2))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR SIGN IN WITH PASSKEY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: tokens.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: tokens.outline.withValues(alpha: 0.2))),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ─── OFFICIAL 180 IDENTITY AUTHENTICATION BUTTON ───
                  OneEightyAuthButton(
                    isLoading: _isLoading,
                    title: _selectedRole == 'ORGANIZER'
                        ? 'Continue as Committee Organizer'
                        : 'Continue as Community Member',
                    subtitle: 'Universal WhatsApp OTP & Biometric Passkey',
                    onPressed: _handle180SignIn,
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'Protected by 180 Sovereign Identity Cloud',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: tokens.onSurfaceVariant.withValues(alpha: 0.7),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
