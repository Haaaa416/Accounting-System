import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// 深色質感主題：近黑底色、金色重點色、綠色收入、珊瑚紅支出
class AppColors {
  static const gold = Color(0xFFE6B450);
  static const goldDeep = Color(0xFFB07D1E);

  static const incomeDark = Color(0xFF34D399);
  static const expenseDark = Color(0xFFF87171);
  static const incomeLight = Color(0xFF059669);
  static const expenseLight = Color(0xFFDC2626);
}

bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color incomeColor(BuildContext context) =>
    isDark(context) ? AppColors.incomeDark : AppColors.incomeLight;

Color expenseColor(BuildContext context) =>
    isDark(context) ? AppColors.expenseDark : AppColors.expenseLight;

/// 金額用的字型樣式：等寬數字，數字對齊比較整齊
TextStyle moneyStyle(double size, FontWeight weight, Color color) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.3,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.gold,
    brightness: brightness,
  ).copyWith(
    primary: dark ? AppColors.gold : AppColors.goldDeep,
    onPrimary: dark ? const Color(0xFF1A1405) : Colors.white,
    surface: dark ? const Color(0xFF0B0E13) : const Color(0xFFF6F5F1),
    onSurface: dark ? const Color(0xFFECEDEE) : const Color(0xFF1B1C1E),
    onSurfaceVariant: dark ? const Color(0xFF9AA3AF) : const Color(0xFF6B7280),
    surfaceContainerLowest: dark ? const Color(0xFF0B0E13) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF141922) : Colors.white,
    surfaceContainer: dark ? const Color(0xFF1A2029) : const Color(0xFFF0EFEA),
    surfaceContainerHigh:
        dark ? const Color(0xFF222935) : const Color(0xFFE8E6DF),
    surfaceContainerHighest:
        dark ? const Color(0xFF2A3240) : const Color(0xFFE0DED6),
    outlineVariant: dark ? const Color(0xFF242B36) : const Color(0xFFE4E2DA),
  );

  final radius = BorderRadius.circular(20);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          )),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.primary.withValues(alpha: 0.18)
                : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainer,
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(color: scheme.onSurface, fontSize: 14),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
  );
}
