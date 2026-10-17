import 'package:flutter/material.dart';

enum AppThemeMode { blue, red }

/// Centralized semantic color tokens. Components must NEVER hardcode hex colors.
abstract class AppColorTokens {
  // Brand / Action
  Color get primary;
  Color get onPrimary;
  Color get primaryContainer;
  Color get onPrimaryContainer;
  Color get secondary;
  Color get onSecondary;

  // Background / Surface
  Color get background;
  Color get onBackground;
  Color get surface;
  Color get onSurface;
  Color get surfaceVariant;
  Color get onSurfaceVariant;
  Color get outline;
  Color get outlineVariant;

  // Semantic Financial Status Tokens (CONSISTENT across Blue and Red themes)
  Color get paidOnTime; // Green
  Color get onPaidOnTime;
  Color get paidOnTimeContainer;

  Color get paidLate; // Orange / Amber
  Color get onPaidLate;
  Color get paidLateContainer;

  Color get unpaidOverdue; // Red
  Color get onUnpaidOverdue;
  Color get unpaidOverdueContainer;

  Color get upcoming; // Neutral Gray
  Color get onUpcoming;
  Color get upcomingContainer;

  Color get partiallyPaid; // Distinct purple/indigo
  Color get onPartiallyPaid;
  Color get partiallyPaidContainer;
}

class BlueColorTokens implements AppColorTokens {
  const BlueColorTokens();

  @override
  Color get primary => const Color(0xFF1E40AF); // Deep Classic Blue
  @override
  Color get onPrimary => Colors.white;
  @override
  Color get primaryContainer => const Color(0xFFDBEAFE);
  @override
  Color get onPrimaryContainer => const Color(0xFF1E3A8A);

  @override
  Color get secondary => const Color(0xFF0284C7); // Sky Accent
  @override
  Color get onSecondary => Colors.white;

  @override
  Color get background => const Color(0xFFF8FAFC);
  @override
  Color get onBackground => const Color(0xFF0F172A);
  @override
  Color get surface => Colors.white;
  @override
  Color get onSurface => const Color(0xFF0F172A);
  @override
  Color get surfaceVariant => const Color(0xFFF1F5F9);
  @override
  Color get onSurfaceVariant => const Color(0xFF475569);
  @override
  Color get outline => const Color(0xFFCBD5E1);
  @override
  Color get outlineVariant => const Color(0xFFE2E8F0);

  // Semantic Status Tokens
  @override
  Color get paidOnTime => const Color(0xFF15803D); // Green 700
  @override
  Color get onPaidOnTime => Colors.white;
  @override
  Color get paidOnTimeContainer => const Color(0xFFDCFCE7);

  @override
  Color get paidLate => const Color(0xFFC2410C); // Orange 700
  @override
  Color get onPaidLate => Colors.white;
  @override
  Color get paidLateContainer => const Color(0xFFFFEDD5);

  @override
  Color get unpaidOverdue => const Color(0xFFB91C1C); // Red 700
  @override
  Color get onUnpaidOverdue => Colors.white;
  @override
  Color get unpaidOverdueContainer => const Color(0xFFFEE2E2);

  @override
  Color get upcoming => const Color(0xFF4B5563); // Gray 600
  @override
  Color get onUpcoming => Colors.white;
  @override
  Color get upcomingContainer => const Color(0xFFF3F4F6);

  @override
  Color get partiallyPaid => const Color(0xFF7C3AED); // Violet 700
  @override
  Color get onPartiallyPaid => Colors.white;
  @override
  Color get partiallyPaidContainer => const Color(0xFFEDE9FE);
}

class RedColorTokens implements AppColorTokens {
  const RedColorTokens();

  // In the Red theme, the primary brand is a rich Garnet / Burgundy.
  // Notice that status tokens (paidOnTime, paidLate, unpaidOverdue) remain
  // semantically intact and use clear labels + icons to prevent confusion.
  @override
  Color get primary => const Color(0xFF991B1B); // Crimson / Garnet
  @override
  Color get onPrimary => Colors.white;
  @override
  Color get primaryContainer => const Color(0xFFFEE2E2);
  @override
  Color get onPrimaryContainer => const Color(0xFF7F1D1D);

  @override
  Color get secondary => const Color(0xFFD97706); // Warm Amber
  @override
  Color get onSecondary => Colors.white;

  @override
  Color get background => const Color(0xFFFFFBEB); // Warm neutral
  @override
  Color get onBackground => const Color(0xFF1C1917);
  @override
  Color get surface => Colors.white;
  @override
  Color get onSurface => const Color(0xFF1C1917);
  @override
  Color get surfaceVariant => const Color(0xFFF5F5F4);
  @override
  Color get onSurfaceVariant => const Color(0xFF57534E);
  @override
  Color get outline => const Color(0xFFD6D3D1);
  @override
  Color get outlineVariant => const Color(0xFFE7E5E4);

  // Semantic Status Tokens (Strictly consistent)
  @override
  Color get paidOnTime => const Color(0xFF15803D); // Green 700
  @override
  Color get onPaidOnTime => Colors.white;
  @override
  Color get paidOnTimeContainer => const Color(0xFFDCFCE7);

  @override
  Color get paidLate => const Color(0xFFC2410C); // Orange 700
  @override
  Color get onPaidLate => Colors.white;
  @override
  Color get paidLateContainer => const Color(0xFFFFEDD5);

  @override
  Color get unpaidOverdue => const Color(0xFFB91C1C); // Red 700
  @override
  Color get onUnpaidOverdue => Colors.white;
  @override
  Color get unpaidOverdueContainer => const Color(0xFFFEE2E2);

  @override
  Color get upcoming => const Color(0xFF4B5563); // Gray 600
  @override
  Color get onUpcoming => Colors.white;
  @override
  Color get upcomingContainer => const Color(0xFFF3F4F6);

  @override
  Color get partiallyPaid => const Color(0xFF7C3AED); // Violet 700
  @override
  Color get onPartiallyPaid => Colors.white;
  @override
  Color get partiallyPaidContainer => const Color(0xFFEDE9FE);
}

ThemeData buildAppTheme(AppColorTokens tokens) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: tokens.primary,
      onPrimary: tokens.onPrimary,
      primaryContainer: tokens.primaryContainer,
      onPrimaryContainer: tokens.onPrimaryContainer,
      secondary: tokens.secondary,
      onSecondary: tokens.onSecondary,
      surface: tokens.surface,
      onSurface: tokens.onSurface,
      error: tokens.unpaidOverdue,
      onError: tokens.onUnpaidOverdue,
    ),
    scaffoldBackgroundColor: tokens.background,
    cardTheme: CardThemeData(
      color: tokens.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: tokens.outlineVariant, width: 1),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.surface,
      foregroundColor: tokens.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: tokens.primary,
        foregroundColor: tokens.onPrimary,
        minimumSize: const Size.fromHeight(48), // Accessible touch target
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
  );
}
