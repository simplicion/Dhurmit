import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:committee_ledger_mobile/main.dart';
import 'package:committee_ledger_mobile/core/theme/theme_provider.dart';
import 'package:committee_ledger_mobile/core/api/api_client.dart';
import 'package:committee_ledger_mobile/core/api/auth_state.dart';
import 'package:committee_ledger_mobile/core/sync/offline_cache_store.dart';
import 'package:committee_ledger_mobile/core/sync/sync_engine.dart';

void main() {
  testWidgets('CommitteeLedgerApp initializes without error', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cacheStore = OfflineCacheStore(prefs: prefs);

    final apiClient = ApiClient(baseUrl: 'http://localhost:3000/api/v1');
    final authState = AuthState(apiClient: apiClient);
    final themeProvider = ThemeProvider();
    final syncEngine = SyncEngine(apiClient: apiClient, cacheStore: cacheStore);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<AuthState>.value(value: authState),
          Provider<OfflineCacheStore>.value(value: cacheStore),
          ChangeNotifierProvider<SyncEngine>.value(value: syncEngine),
        ],
        child: const CommitteeLedgerApp(),
      ),
    );

    expect(find.byType(CommitteeLedgerApp), findsOneWidget);
  });
}
