import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/auth_state.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/one_eighty_auth_button.dart';
import '../../../core/widgets/one_eighty_launcher.dart';
import '../../../core/location/country_provider.dart';
import '../../../core/location/country_picker_bottom_sheet.dart';
import 'member_login_bottom_sheet.dart';

/// Primary Login Screen for Dhurmit.
/// Clean, minimalist, and focused:
/// - Official Dhurmit branding logo & title
/// - Dynamic Country selector (OpenStreetMap)
/// - Official 180 Identity SSO Button for Committee Organizers
/// - Direct "Join as a Member" button opening MemberLoginBottomSheet
/// - Sign in once with internet; all subsequent app usage operates fully offline
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

      if (kIsWeb) {
        final origin = Uri.base.origin.contains('http')
            ? Uri.base.origin
            : 'http://localhost:3000';
        final redirectUri = '$origin/auth/callback';

        // Launch 180 SDK native bottom sheet modal on Web
        final authResultJson = await trigger180WebBottomSheet(clientId, redirectUri);
        if (!mounted) return;

        if (authResultJson != null && authResultJson.isNotEmpty) {
          final authState = context.read<AuthState>();
          String? authCode;
          Map<String, dynamic>? userPayload;

          try {
            final data = jsonDecode(authResultJson) as Map<String, dynamic>;
            if (data['cancelled'] == true) {
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
              userType: 'ORGANIZER',
            );
            if (mounted) {
              context.go('/home');
            }
            return;
          }
        }
      } else {
        // Mobile platform (Android / iOS):
        // Launch official 180 Sovereign Identity SSO in browser
        const mobileRedirectUri = 'https://dhurmit.simplicion.com/auth/callback';
        final authUrl = Uri.parse(
          'https://auth.180workspace.com/auth/login?'
          'client_id=$clientId&'
          'redirect_uri=${Uri.encodeComponent(mobileRedirectUri)}&'
          'response_type=code&'
          'scope=${Uri.encodeComponent('openid identity:read identity:email identity:phone')}&'
          'app=auth',
        );

        if (await canLaunchUrl(authUrl)) {
          await launchUrl(authUrl, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot launch browser. Please verify internet connection and browser availability.'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('180 Identity notice: $e'),
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

                  // ─── DESCRIPTION ───
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

                  const SizedBox(height: 24),

                  // ─── COUNTRY & CURRENCY SELECTION CHIP (OpenStreetMap) ───
                  Consumer<CountryProvider>(
                    builder: (context, countryProvider, _) {
                      final country = countryProvider.activeCountry;
                      return Center(
                        child: InkWell(
                          onTap: () => CountryPickerBottomSheet.show(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: tokens.surfaceVariant.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: tokens.outlineVariant),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(country.flag, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Text(
                                  '${country.name} (${country.currencyCode} ${country.currencySymbol})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: tokens.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down_rounded, size: 18, color: tokens.onSurfaceVariant),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // ─── OFFICIAL 180 IDENTITY AUTHENTICATION BUTTON FOR ORGANIZER ───
                  OneEightyAuthButton(
                    isLoading: _isLoading,
                    title: 'Continue as Committee Organizer',
                    subtitle: 'Universal WhatsApp OTP & Biometric Passkey',
                    onPressed: _handle180SignIn,
                  ),

                  const SizedBox(height: 14),

                  // ─── JOIN AS A MEMBER BUTTON ───
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.primary,
                      side: BorderSide(
                        color: tokens.primary.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: tokens.surface,
                    ),
                    onPressed: () => MemberLoginBottomSheet.show(context),
                    icon: const Icon(Icons.group_add_rounded, size: 20),
                    label: const Text(
                      'Join as a Member',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ─── SECURITY FOOTER ───
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
