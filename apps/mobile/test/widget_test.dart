import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:committee_ledger_mobile/main.dart';
import 'package:committee_ledger_mobile/core/theme/theme_provider.dart';
import 'package:committee_ledger_mobile/core/api/api_client.dart';
import 'package:committee_ledger_mobile/core/api/auth_state.dart';

void main() {
  testWidgets('CommitteeLedgerApp initializes without error', (WidgetTester tester) async {
    final apiClient = ApiClient(baseUrl: 'http://localhost:3000/api/v1');
    final authState = AuthState(apiClient: apiClient);
    final themeProvider = ThemeProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<AuthState>.value(value: authState),
        ],
        child: const CommitteeLedgerApp(),
      ),
    );

    expect(find.byType(CommitteeLedgerApp), findsOneWidget);
  });
}
