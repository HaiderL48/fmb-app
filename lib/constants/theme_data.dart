import 'package:flutter/material.dart';
import 'colors.dart';
import 'styles.dart';

/// Global ThemeData used in MaterialApp.
/// Light theme uses FMB brand colors; dark theme uses CSS.css dark variables.
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Gotham', // Gotham Rounded — declare in pubspec.yaml
  // ─── Color Scheme ──────────────────────────────────────────────────────────
  colorScheme: const ColorScheme.light(
    primary: AppColors.fmbPrimary,
    onPrimary: AppColors.fmbAccent,
    primaryContainer: AppColors.fmbPrimaryDark,
    onPrimaryContainer: AppColors.primaryForeground,
    secondary: AppColors.secondary,
    onSecondary: AppColors.secondaryForeground,
    surface: AppColors.background,
    onSurface: AppColors.foreground,
    error: AppColors.destructive,
    onError: AppColors.destructiveForeground,
    outline: AppColors.border,
  ),

  // ─── Scaffold ──────────────────────────────────────────────────────────────
  scaffoldBackgroundColor: AppColors.background,

  // ─── AppBar ────────────────────────────────────────────────────────────────
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.fmbPrimary,
    foregroundColor: AppColors.fmbAccent,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: 18.0,
      fontWeight: FontWeight.w600,
      color: AppColors.fmbAccent,
      fontFamily: 'Gotham',
    ),
  ),

  // ─── Card ──────────────────────────────────────────────────────────────────
  cardTheme: CardThemeData(
    color: AppColors.card,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.xlAll,
      side: const BorderSide(color: AppColors.border, width: 1),
    ),
    shadowColor: Colors.black12,
  ),

  // ─── Elevated Button (FMB Primary style) ───────────────────────────────────
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.fmbPrimary,
      foregroundColor: AppColors.fmbAccent,
      minimumSize: const Size.fromHeight(48), // h-12
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      textStyle: AppTextStyle.button,
      elevation: 0,
    ),
  ),

  // ─── Outlined Button ───────────────────────────────────────────────────────
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.fmbPrimary,
      side: const BorderSide(color: AppColors.border),
      minimumSize: const Size.fromHeight(40),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      textStyle: AppTextStyle.button,
    ),
  ),

  // ─── Text Button ───────────────────────────────────────────────────────────
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.fmbPrimary,
      textStyle: AppTextStyle.button,
    ),
  ),

  // ─── Input Decoration ──────────────────────────────────────────────────────
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.inputBackground,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.s3,
      vertical: AppSpacing.s2,
    ),
    border: OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: const BorderSide(color: AppColors.ring, width: 3),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: const BorderSide(color: AppColors.destructive, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: AppRadius.mdAll,
      borderSide: const BorderSide(color: AppColors.destructive, width: 2),
    ),
    hintStyle: AppTextStyle.muted,
    labelStyle: AppTextStyle.label,
  ),

  // ─── Divider ───────────────────────────────────────────────────────────────
  dividerTheme: const DividerThemeData(
    color: AppColors.border,
    thickness: 1,
    space: 0,
  ),

  // ─── Chip ──────────────────────────────────────────────────────────────────
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.accent,
    labelStyle: AppTextStyle.bodySm.copyWith(color: AppColors.accentForeground),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.fullAll),
    side: BorderSide.none,
  ),

  // ─── Bottom Navigation Bar ─────────────────────────────────────────────────
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.background,
    selectedItemColor: AppColors.fmbPrimary,
    unselectedItemColor: AppColors.gray400,
    elevation: 8,
    type: BottomNavigationBarType.fixed,
  ),

  // ─── Text Theme ────────────────────────────────────────────────────────────
  textTheme: const TextTheme(
    displayLarge: AppTextStyle.h1,
    displayMedium: AppTextStyle.h2,
    displaySmall: AppTextStyle.h3,
    headlineMedium: AppTextStyle.h4,
    bodyLarge: AppTextStyle.bodyBase,
    bodyMedium: AppTextStyle.bodySm,
    bodySmall: AppTextStyle.bodyXs,
    labelLarge: AppTextStyle.label,
  ),
);

/// Dark theme — uses CSS.css .dark variables
final ThemeData appDarkTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Gotham',
  brightness: Brightness.dark,

  colorScheme: const ColorScheme.dark(
    primary: AppColors.fmbPrimary,
    onPrimary: AppColors.fmbAccent,
    surface: AppColors.darkBackground,
    onSurface: AppColors.darkForeground,
    error: AppColors.darkDestructive,
    outline: AppColors.darkBorder,
  ),

  scaffoldBackgroundColor: AppColors.darkBackground,

  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.darkBackground,
    foregroundColor: AppColors.darkForeground,
    elevation: 0,
  ),

  cardTheme: CardThemeData(
    color: AppColors.darkCard,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.xlAll,
      side: const BorderSide(color: AppColors.darkBorder, width: 1),
    ),
  ),

  dividerTheme: const DividerThemeData(
    color: AppColors.darkBorder,
    thickness: 1,
  ),
);
