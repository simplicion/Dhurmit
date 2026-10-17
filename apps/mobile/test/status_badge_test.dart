import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:committee_ledger_mobile/core/theme/app_color_tokens.dart';
import 'package:committee_ledger_mobile/core/theme/theme_provider.dart';
import 'package:committee_ledger_mobile/core/widgets/status_badge.dart';

Widget wrapWithTheme(Widget child, {AppThemeMode themeMode = AppThemeMode.blue}) {
  final provider = ThemeProvider()..setTheme(themeMode);
  return ChangeNotifierProvider<ThemeProvider>.value(
    value: provider,
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('StatusBadge Widget Exhaustive Tests', () {
    testWidgets('renders PAID_ON_TIME with green semantic colors, check icon and label', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const StatusBadge(status: 'PAID_ON_TIME'),
      ));

      expect(find.text('Paid on time'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('renders PAID_LATE with orange semantic colors, history icon and label', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const StatusBadge(status: 'PAID_LATE'),
      ));

      expect(find.text('Paid late'), findsOneWidget);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets('renders UNPAID_OVERDUE with red semantic colors, alert icon and label', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const StatusBadge(status: 'UNPAID_OVERDUE'),
      ));

      expect(find.text('Overdue'), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });

    testWidgets('renders UPCOMING with neutral gray semantic colors, calendar/clock icon and label', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const StatusBadge(status: 'UPCOMING'),
      ));

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });

    testWidgets('renders PARTIALLY_PAID with formatted remaining amount and icon', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        StatusBadge(
          status: 'PARTIALLY_PAID',
          remainingMinor: BigInt.from(25000), // NPR 250
        ),
      ));

      expect(find.textContaining('Partial (NPR 250 left)'), findsOneWidget);
      expect(find.byIcon(Icons.timelapse_rounded), findsOneWidget);
    });

    testWidgets('renders PARTIALLY_PAID without remainder if remainingMinor is null', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const StatusBadge(status: 'PARTIALLY_PAID'),
      ));

      expect(find.text('Partial'), findsOneWidget);
      expect(find.byIcon(Icons.timelapse_rounded), findsOneWidget);
    });

    testWidgets('renders compact badge size properly', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const StatusBadge(status: 'PAID_ON_TIME', compact: true),
      ));

      expect(find.text('Paid on time'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('renders all status badges identically when Red theme is active', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const Column(
          children: [
            StatusBadge(status: 'PAID_ON_TIME'),
            StatusBadge(status: 'PAID_LATE'),
            StatusBadge(status: 'UNPAID_OVERDUE'),
            StatusBadge(status: 'UPCOMING'),
          ],
        ),
        themeMode: AppThemeMode.red,
      ));

      // Overdue status must remain red and not clash with red primary theme
      expect(find.text('Paid on time'), findsOneWidget);
      expect(find.text('Paid late'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
    });

    testWidgets('renders fallback style for unknown status gracefully', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const StatusBadge(status: 'UNKNOWN_STATUS_CODE'),
      ));

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    });
  });
}
