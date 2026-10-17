import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:committee_ledger_mobile/core/theme/app_color_tokens.dart';
import 'package:committee_ledger_mobile/core/theme/theme_provider.dart';
import 'package:committee_ledger_mobile/core/api/auth_state.dart';
import 'package:committee_ledger_mobile/core/api/api_client.dart';
import 'package:committee_ledger_mobile/features/settings/presentation/settings_screen.dart';
import 'package:committee_ledger_mobile/features/authentication/presentation/login_screen.dart';

Widget wrapAppShell(Widget child, {ThemeProvider? themeProvider, AuthState? authState}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => themeProvider ?? ThemeProvider(),
      ),
      ChangeNotifierProvider<AuthState>(
        create: (_) => authState ?? AuthState(apiClient: ApiClient(baseUrl: 'http://localhost:4000/api/v1')),
      ),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('Screen Flow & Interaction Tests', () {
    testWidgets('LoginScreen renders email input, password input, and Sign In button', (tester) async {
      await tester.pumpWidget(wrapAppShell(const LoginScreen()));

      expect(find.text('Committee Ledger'), findsOneWidget);
      expect(find.text('Sign in to manage your committees'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text("Don't have an account? Sign Up"), findsOneWidget);
    });

    testWidgets('SettingsScreen displays theme options and switches active theme on tap', (tester) async {
      final themeProvider = ThemeProvider();
      await tester.pumpWidget(wrapAppShell(
        const SettingsScreen(),
        themeProvider: themeProvider,
      ));

      expect(find.text('Settings & Preferences'), findsOneWidget);
      expect(find.text('App Theme'), findsOneWidget);
      expect(find.text('Blue Theme'), findsOneWidget);
      expect(find.text('Red Theme'), findsOneWidget);

      // Initially Blue is selected
      expect(themeProvider.mode, equals(AppThemeMode.blue));

      // Tap on Red theme
      await tester.tap(find.text('Red Theme'));
      await tester.pumpAndSettle();

      // Theme provider should now be set to Red
      expect(themeProvider.mode, equals(AppThemeMode.red));
    });

    testWidgets('SettingsScreen contains legal boundaries disclaimer', (tester) async {
      await tester.pumpWidget(wrapAppShell(const SettingsScreen()));

      expect(find.text('Legal & Operational Notice'), findsOneWidget);
      expect(
        find.textContaining('Software recordkeeping tool for organizers replacing paper notebooks.'),
        findsOneWidget,
      );
    });
  });
}
