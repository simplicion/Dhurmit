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

                  const SizedBox(height: 40),

                  // ─── OFFICIAL 180 IDENTITY AUTHENTICATION BUTTON ───
                  OneEightyAuthButton(
                    isLoading: _isLoading,
                    title: 'Continue with 180 Profile',
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
