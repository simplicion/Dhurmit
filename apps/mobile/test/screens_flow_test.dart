import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:committee_ledger_mobile/core/theme/app_color_tokens.dart';
import 'package:committee_ledger_mobile/core/theme/theme_provider.dart';
import 'package:committee_ledger_mobile/core/api/auth_state.dart';
import 'package:committee_ledger_mobile/core/api/api_client.dart';
import 'package:committee_ledger_mobile/core/sync/offline_cache_store.dart';
import 'package:committee_ledger_mobile/core/sync/sync_engine.dart';
import 'package:committee_ledger_mobile/features/settings/presentation/settings_screen.dart';
import 'package:committee_ledger_mobile/features/authentication/presentation/login_screen.dart';
import 'package:committee_ledger_mobile/features/home/presentation/home_dashboard_screen.dart';

Widget wrapAppShell(
  Widget child, {
  ThemeProvider? themeProvider,
  AuthState? authState,
  SyncEngine? syncEngine,
  OfflineCacheStore? cacheStore,
}) {
  final client = ApiClient(baseUrl: 'http://localhost:4000/api/v1');
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => themeProvider ?? ThemeProvider(),
      ),
      ChangeNotifierProvider<AuthState>(
        create: (_) => authState ?? AuthState(apiClient: client),
      ),
      if (cacheStore != null) Provider<OfflineCacheStore>.value(value: cacheStore),
      if (syncEngine != null) ChangeNotifierProvider<SyncEngine>.value(value: syncEngine),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late OfflineCacheStore cacheStore;
  late SyncEngine syncEngine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cacheStore = OfflineCacheStore(prefs: prefs);
    syncEngine = SyncEngine(
      apiClient: ApiClient(baseUrl: 'http://localhost:4000/api/v1'),
      cacheStore: cacheStore,
    );
  });

  group('Screen Flow & Interaction Tests', () {
    testWidgets('LoginScreen renders app purpose and official 180 Identity button without legacy form fields', (tester) async {
      await tester.pumpWidget(wrapAppShell(
        const LoginScreen(),
        syncEngine: syncEngine,
        cacheStore: cacheStore,
      ));

      expect(find.text('DHURMIT'), findsOneWidget);
      expect(find.text('COMMITTEE MANAGEMENT & FINANCIAL LEDGER'), findsOneWidget);
      expect(find.textContaining('Automated committee ledgers and contribution tracking'), findsOneWidget);
      expect(find.text('Continue with 180 Profile'), findsOneWidget);
      expect(find.text('Protected by 180 Sovereign Identity Cloud'), findsOneWidget);

      // Verify legacy cards and form inputs are deleted
      expect(find.text('Automated Committee Ledgers'), findsNothing);
      expect(find.text('Lump-Sum Allocation'), findsNothing);
      expect(find.text('Email Address'), findsNothing);
      expect(find.text('Password'), findsNothing);
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('Tapping Continue with 180 Profile initiates direct 180 sign-in without intermediate modal', (tester) async {
      await tester.pumpWidget(wrapAppShell(
        const LoginScreen(),
        syncEngine: syncEngine,
        cacheStore: cacheStore,
      ));

      final button = find.text('Continue with 180 Profile');
      expect(button, findsOneWidget);

      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();

      // No redundant Flutter modal sheet is opened
      expect(find.text('Verify & Enter App'), findsNothing);
      expect(find.text('Launch 180 Sovereign Sign-In'), findsNothing);
    });

    testWidgets('SettingsScreen displays theme options and switches active theme on tap', (tester) async {
      final themeProvider = ThemeProvider();
      await tester.pumpWidget(wrapAppShell(
        const SettingsScreen(),
        themeProvider: themeProvider,
        syncEngine: syncEngine,
        cacheStore: cacheStore,
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

    testWidgets('SettingsScreen displays Offline Sync & Storage card and Legal Notice', (tester) async {
      await tester.pumpWidget(wrapAppShell(
        const SettingsScreen(),
        syncEngine: syncEngine,
        cacheStore: cacheStore,
      ));

      expect(find.text('Offline Sync & Storage'), findsOneWidget);
      expect(find.text('Queued Changes: 0'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Legal & Operational Notice'), findsOneWidget);
      expect(
        find.textContaining('Software recordkeeping tool for organizers replacing paper notebooks.'),
        findsOneWidget,
      );
    });

    testWidgets('HomeDashboardScreen switches tabs to Settings without layout error', (tester) async {
      await tester.pumpWidget(wrapAppShell(
        const HomeDashboardScreen(),
        syncEngine: syncEngine,
        cacheStore: cacheStore,
      ));
      await tester.pump();

      // Tap on Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings & Preferences'), findsOneWidget);
      expect(find.text('App Theme'), findsOneWidget);
    });

    testWidgets('SettingsScreen renders correctly when user and workspace are authenticated', (tester) async {
      await prefs.setString('auth_token', 'mock_token_123');
      await prefs.setString('user_data', '{"id":"user_1","displayName":"Dhurmit Leader","email":"leader@dhurmit.com"}');
      await prefs.setString('workspace_data', '{"id":"ws_1","name":"Kathmandu Committee","role":"OWNER"}');

      final auth = AuthState(apiClient: ApiClient(baseUrl: 'http://localhost:4000/api/v1'));
      await auth.checkAuth();

      await tester.pumpWidget(wrapAppShell(
        const HomeDashboardScreen(),
        authState: auth,
        syncEngine: syncEngine,
        cacheStore: cacheStore,
      ));
      await tester.pumpAndSettle();

      // Tap Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings & Preferences'), findsOneWidget);
      expect(find.text('Dhurmit Leader'), findsOneWidget);
      expect(find.text('Kathmandu Committee'), findsOneWidget);
      expect(find.text('App Theme'), findsOneWidget);
    });
  });
}


