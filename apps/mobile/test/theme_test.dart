import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:committee_ledger_mobile/core/theme/app_color_tokens.dart';
import 'package:committee_ledger_mobile/core/theme/theme_provider.dart';

void main() {
  group('AppColorTokens & Theme System Tests', () {
    const blue = BlueColorTokens();
    const red = RedColorTokens();

    test('primary brand colors differ between Blue and Red themes', () {
      expect(blue.primary, equals(const Color(0xFF1E40AF)));
      expect(red.primary, equals(const Color(0xFF991B1B)));
      expect(blue.primary, isNot(equals(red.primary)));
    });

    test('secondary and background surfaces adhere to theme tokens', () {
      expect(blue.primaryContainer, equals(const Color(0xFFDBEAFE)));
      expect(red.primaryContainer, equals(const Color(0xFFFEE2E2)));
      expect(blue.background, equals(const Color(0xFFF8FAFC)));
      expect(red.background, equals(const Color(0xFFFFFBEB)));
    });

    test('semantic status colors are strictly identical and consistent across both themes', () {
      // Green = Paid On Time
      expect(blue.paidOnTime, equals(red.paidOnTime));
      expect(blue.paidOnTime, equals(const Color(0xFF15803D)));
      expect(blue.paidOnTimeContainer, equals(red.paidOnTimeContainer));

      // Orange = Paid Late
      expect(blue.paidLate, equals(red.paidLate));
      expect(blue.paidLate, equals(const Color(0xFFC2410C)));
      expect(blue.paidLateContainer, equals(red.paidLateContainer));

      // Red = Overdue
      expect(blue.unpaidOverdue, equals(red.unpaidOverdue));
      expect(blue.unpaidOverdue, equals(const Color(0xFFB91C1C)));
      expect(blue.unpaidOverdueContainer, equals(red.unpaidOverdueContainer));

      // Neutral Gray = Upcoming
      expect(blue.upcoming, equals(red.upcoming));
      expect(blue.upcoming, equals(const Color(0xFF4B5563)));
      expect(blue.upcomingContainer, equals(red.upcomingContainer));

      // Violet = Partially Paid
      expect(blue.partiallyPaid, equals(red.partiallyPaid));
      expect(blue.partiallyPaid, equals(const Color(0xFF7C3AED)));
      expect(blue.partiallyPaidContainer, equals(red.partiallyPaidContainer));
    });

    test('ThemeData generated from tokens has required Material 3 and component properties', () {
      final blueTheme = buildAppTheme(blue);
      final redTheme = buildAppTheme(red);

      expect(blueTheme.useMaterial3, isTrue);
      expect(redTheme.useMaterial3, isTrue);

      expect(blueTheme.colorScheme.primary, equals(blue.primary));
      expect(redTheme.colorScheme.primary, equals(red.primary));

      expect(blueTheme.scaffoldBackgroundColor, equals(blue.background));
      expect(redTheme.scaffoldBackgroundColor, equals(red.background));

      expect(blueTheme.cardTheme.elevation, equals(0));
      expect(redTheme.cardTheme.elevation, equals(0));
    });

    test('ThemeProvider initializes with Blue theme by default and can switch themes', () {
      final provider = ThemeProvider();
      expect(provider.mode, equals(AppThemeMode.blue));
      expect(provider.tokens.primary, equals(const Color(0xFF1E40AF)));

      // Switch to red
      provider.setTheme(AppThemeMode.red);
      expect(provider.mode, equals(AppThemeMode.red));
      expect(provider.tokens.primary, equals(const Color(0xFF991B1B)));

      // Toggle back to blue
      provider.toggleTheme();
      expect(provider.mode, equals(AppThemeMode.blue));
    });

    test('ThemeProvider notifies listeners on theme change', () {
      final provider = ThemeProvider();
      var notificationCount = 0;
      provider.addListener(() {
        notificationCount++;
      });

      provider.setTheme(AppThemeMode.red);
      expect(notificationCount, equals(1));

      provider.setTheme(AppThemeMode.blue);
      expect(notificationCount, equals(2));
    });
  });
}
