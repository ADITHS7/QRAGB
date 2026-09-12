import 'package:flutter/material.dart';

import 'models/app_type.dart';

/// Colors shared by custom-painted surfaces that cannot read [Theme.of].
abstract final class AppColors {
  static const scrim = Color(0xB3000000);
}

/// The visual identity used by one operating mode of the app.
class AppThemePalette {
  const AppThemePalette({
    required this.accent,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.onAccent,
  });

  static const food = AppThemePalette(
    // Warm orange/coral food-service palette.
    accent: Color(0xFFFF6B35),
    secondary: Color(0xFFFF9F1C),
    background: Color(0xFF140D0A),
    surface: Color(0xFF1F1410),
    surfaceHigh: Color(0xFF2B1C15),
    onAccent: Colors.black,
  );

  static const gift = AppThemePalette(
    accent: Color(0xFFEC4899),
    secondary: Color(0xFFF472B6),
    background: Color(0xFF180D17),
    surface: Color(0xFF261022),
    surfaceHigh: Color(0xFF35152E),
    onAccent: Colors.white,
  );

  static const entry = AppThemePalette(
    accent: Color(0xFF2563EB),
    secondary: Color(0xFF60A5FA),
    background: Color(0xFF08111F),
    surface: Color(0xFF0F1C2E),
    surfaceHigh: Color(0xFF162A43),
    onAccent: Colors.white,
  );

  final Color accent;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color onAccent;

  static AppThemePalette forType(AppType type) => switch (type) {
    AppType.food => food,
    AppType.gift => gift,
    AppType.entry => entry,
  };
}

ThemeData buildAppTheme([AppType appType = AppType.food]) {
  final palette = AppThemePalette.forType(appType);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: palette.accent,
        onPrimary: palette.onAccent,
        secondary: palette.secondary,
        onSecondary: palette.onAccent,
        surface: palette.surface,
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white70,
      );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.surface,
    cardColor: palette.surfaceHigh,
    dialogTheme: DialogThemeData(backgroundColor: palette.surface),
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.surface,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Colors.white38,
    ),
    dividerTheme: const DividerThemeData(color: Colors.white12),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surfaceHigh,
      contentTextStyle: const TextStyle(color: Colors.white),
      actionTextColor: palette.secondary,
    ),
    // Page transitions are kept snappy: the scanner should never feel like it
    // is waiting on animation.
    splashFactory: InkSparkle.splashFactory,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: Colors.white,
        side: BorderSide(color: palette.accent.withValues(alpha: 0.65)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
