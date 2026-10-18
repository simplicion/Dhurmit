import 'package:flutter/material.dart';
import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/theme_provider.dart';
import 'package:provider/provider.dart';

/// Instant startup splash screen displayed on Frame 1 while AuthState loads.
/// Ensures Android OS native splash screen dismisses instantly and provides
/// a smooth, branded transition to either /home or /login.
class StartupSplashScreen extends StatelessWidget {
  const StartupSplashScreen({super.key});

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
