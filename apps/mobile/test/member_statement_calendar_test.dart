import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:committee_ledger_mobile/core/api/api_client.dart';
import 'package:committee_ledger_mobile/core/api/auth_state.dart';
import 'package:committee_ledger_mobile/core/location/country_provider.dart';
import 'package:committee_ledger_mobile/core/theme/theme_provider.dart';
import 'package:committee_ledger_mobile/features/members/presentation/member_statement_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MemberStatementScreen renders interactive calendar with month navigation and tap-to-inspect date details', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final mockResponse = {
      'member': {
        'id': 'mem_1',
        'displayName': 'Rahul Sharma',
        'phone': '9841234567',
      },
      'statement': {
        'totalDueMinor': 6000000,
        'totalPaidMinor': 0,
        'totalOutstandingMinor': 6000000,
        'obligations': [
          {
            'sequenceNumber': 1,
            'dueDate': '2026-10-16',
            'amountMinor': 200000,
            'outstandingMinor': 200000,
            'status': 'UNPAID_OVERDUE',
            'allocations': <Map<String, dynamic>>[],
          },
          {
            'sequenceNumber': 2,
            'dueDate': '2026-10-17',
            'amountMinor': 200000,
            'outstandingMinor': 200000,
            'status': 'UNPAID_OVERDUE',
            'allocations': <Map<String, dynamic>>[],
          },
          {
            'sequenceNumber': 3,
            'dueDate': '2026-10-18',
            'amountMinor': 200000,
            'outstandingMinor': 200000,
            'status': 'UPCOMING',
            'allocations': <Map<String, dynamic>>[],
          },
        ],
      },
    };

    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode(mockResponse),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = ApiClient(baseUrl: 'http://localhost:4000/api/v1', httpClient: mockClient);
    final authState = AuthState(apiClient: apiClient);
    final themeProvider = ThemeProvider();
    final countryProvider = CountryProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<AuthState>.value(value: authState),
          ChangeNotifierProvider<CountryProvider>.value(value: countryProvider),
        ],
        child: const MaterialApp(
          home: MemberStatementScreen(
            committeeId: 'comm_1',
            memberId: 'mem_1',
          ),
        ),
      ),
    );

    // Pump to settle async HTTP load
    await tester.pumpAndSettle();

    // Verify Member header and financial summaries
    expect(find.text('Member Statement'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('9841234567'), findsOneWidget);
    expect(find.text('Total Due'), findsOneWidget);

    // Verify Interactive Calendar components
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);

    // Verify days of the week
    expect(find.text('Sun'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Tue'), findsOneWidget);
    expect(find.text('Wed'), findsOneWidget);
    expect(find.text('Thu'), findsOneWidget);
    expect(find.text('Fri'), findsOneWidget);
    expect(find.text('Sat'), findsOneWidget);

    // Scroll down to make calendar grid visible
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();

    // Verify day 16 (the overdue obligation) is rendered on the calendar
    expect(find.text('16'), findsOneWidget);

    // Tap on date 16 to open bottom sheet details
    await tester.tap(find.text('16'));
    await tester.pumpAndSettle();

    // Bottom sheet details modal should display the obligation information
    expect(find.textContaining('Friday, October 16, 2026'), findsWidgets);
    expect(find.text('#1 Due: 2026-10-16'), findsWidgets);

    // Dismiss bottom sheet via close icon
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Scroll back up to the view switcher and tap List
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    // List view should show dues
    expect(find.text('#1 Due: 2026-10-16'), findsWidgets);
    expect(find.text('#2 Due: 2026-10-17'), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('#3 Due: 2026-10-18'), findsWidgets);
  });
}
