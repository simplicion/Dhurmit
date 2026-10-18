import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/auth_state.dart';
import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/theme_provider.dart';
import 'package:provider/provider.dart';

/// Instant startup splash screen displayed on Frame 1 while AuthState loads.
/// Ensures Android OS native splash screen dismisses instantly and provides
/// a smooth, branded transition to either /home or /login.
class StartupSplashScreen extends StatefulWidget {
  const StartupSplashScreen({super.key});

  @override
  State<StartupSplashScreen> createState() => _StartupSplashScreenState();
}

class _StartupSplashScreenState extends State<StartupSplashScreen> {
  Timer? _watchdogTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watchdogTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        try {
          final auth = context.read<AuthState>();
          if (auth.isAuthenticated) {
            context.go('/home');
          } else {
            context.go('/login');
          }
        } catch (_) {
          // If AuthState is not mounted yet, DhurmitAppBootstrap will swap to CommitteeLedgerApp shortly
        }
      });
    });
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColorTokens tokens = const BlueColorTokens();
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: true);
      tokens = themeProvider.tokens;
    } catch (_) {
      tokens = const BlueColorTokens();
    }

    return Scaffold(
      backgroundColor: tokens.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 100,
                  width: 100,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'DHURMIT',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: tokens.onBackground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'COMMITTEE MANAGEMENT & FINANCIAL LEDGER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: tokens.primary,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: tokens.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
