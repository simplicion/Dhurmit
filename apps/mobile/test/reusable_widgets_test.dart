import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:committee_ledger_mobile/core/theme/theme_provider.dart';
import 'package:committee_ledger_mobile/core/widgets/primary_button.dart';
import 'package:committee_ledger_mobile/core/widgets/money_input_field.dart';
import 'package:committee_ledger_mobile/core/widgets/state_widgets.dart';

Widget wrapWithTheme(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16.0), child: child)),
    ),
  );
}

void main() {
  group('PrimaryButton Widget Tests', () {
    testWidgets('renders elevated button with label and responds to tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapWithTheme(
        PrimaryButton(
          label: 'Submit Collection',
          onPressed: () => tapped = true,
        ),
      ));

      expect(find.text('Submit Collection'), findsOneWidget);
      await tester.tap(find.text('Submit Collection'));
      expect(tapped, isTrue);
    });

    testWidgets('renders outlined button variant properly', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        PrimaryButton(
          label: 'Cancel Action',
          isOutlined: true,
          onPressed: () {},
        ),
      ));

      expect(find.text('Cancel Action'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('renders loading spinner and ignores taps when isLoading is true', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapWithTheme(
        PrimaryButton(
          label: 'Saving Record',
          isLoading: true,
          onPressed: () => tapped = true,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Saving Record'), findsNothing);

      await tester.tap(find.byType(PrimaryButton));
      expect(tapped, isFalse);
    });

    testWidgets('renders leading icon when provided', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        PrimaryButton(
          label: 'Add Member',
          icon: Icons.person_add,
          onPressed: () {},
        ),
      ));

      expect(find.byIcon(Icons.person_add), findsOneWidget);
      expect(find.text('Add Member'), findsOneWidget);
    });
  });

  group('MoneyInputField Widget Tests', () {
    testWidgets('renders with label and NPR prefix', (tester) async {
      final controller = TextEditingController(text: '1500');
      await tester.pumpWidget(wrapWithTheme(
        MoneyInputField(
          controller: controller,
          label: 'Contribution Amount',
        ),
      ));

      expect(find.text('Contribution Amount'), findsOneWidget);
      expect(find.text('Rs. '), findsOneWidget);
      expect(find.text('1500'), findsOneWidget);
    });

    testWidgets('updates text value when typed into', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(wrapWithTheme(
        MoneyInputField(
          controller: controller,
          label: 'Amount Due',
        ),
      ));

      await tester.enterText(find.byType(TextFormField), '2500.50');
      expect(controller.text, equals('2500.50'));
    });
  });

  group('State Widgets Tests (Empty, Loading, Error)', () {
    testWidgets('LoadingState renders spinner and optional message', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const LoadingState(message: 'Fetching ledger history...'),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Fetching ledger history...'), findsOneWidget);
    });

    testWidgets('EmptyState renders title, subtitle, and action button', (tester) async {
      var actionTapped = false;
      await tester.pumpWidget(wrapWithTheme(
        EmptyState(
          icon: Icons.group_off_rounded,
          title: 'No Committees Found',
          description: 'Create your first committee to start recording dues.',
          actionLabel: 'Create Committee',
          onAction: () => actionTapped = true,
        ),
      ));

      expect(find.text('No Committees Found'), findsOneWidget);
      expect(find.text('Create your first committee to start recording dues.'), findsOneWidget);
      expect(find.text('Create Committee'), findsOneWidget);

      await tester.tap(find.text('Create Committee'));
      expect(actionTapped, isTrue);
    });

    testWidgets('ErrorState renders error icon, message, and retry button', (tester) async {
      var retried = false;
      await tester.pumpWidget(wrapWithTheme(
        ErrorState(
          message: 'Failed to connect to backend API server.',
          onRetry: () => retried = true,
        ),
      ));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Failed to connect to backend API server.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });
}
