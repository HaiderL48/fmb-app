import 'package:flutter/material.dart';

/// FMB brand colors and all system colors extracted from CSS.css / STYLE_GUIDE.md
class AppColors {
  AppColors._();

  // ─── FMB Brand Colors ────────────────────────────────────────────────────
  static const Color fmbPrimary = Color(0xFF2D6A7E); // Main bg, primary buttons
  static const Color fmbButtonGreen = Color(
    0xFF009966,
  ); // Main bg, primary buttons
  static const Color fmbPrimaryDark = Color(
    0xFF1E5A6D,
  ); // Hover / darker gradient
  static const Color fmbAccent = Color(
    0xFFFFC107,
  ); // Gold — text on primary, highlights
  static const Color fmbAccentDark = Color(
    0xFFFFB300,
  ); // Hover for gold elements

  // ─── System / Semantic Colors ────────────────────────────────────────────
  static const Color background = Color(0xFFFFFFFF);
  static const Color foreground = Color(
    0xFF0A0A0A,
  ); // oklch(0.145 0 0) ≈ #0A0A0A
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardForeground = Color(0xFF0A0A0A);
  static const Color popover = Color(0xFFFFFFFF);
  static const Color popoverForeground = Color(0xFF0A0A0A);

  static const Color primary = Color(0xFF030213);
  static const Color primaryForeground = Color(0xFFFFFFFF); // oklch(1 0 0)
  static const Color secondary = Color(
    0xFFF1F1F8,
  ); // oklch(0.95 0.0058 264.53) ≈
  static const Color secondaryForeground = Color(0xFF030213);

  static const Color muted = Color(0xFFECECF0);
  static const Color mutedForeground = Color(0xFF717182);
  static const Color accent = Color(0xFFE9EBEF);
  static const Color accentForeground = Color(0xFF030213);

  static const Color destructive = Color(0xFFD4183D);
  static const Color destructiveForeground = Color(0xFFFFFFFF);

  static const Color border = Color(0x1A000000); // rgba(0,0,0,0.1)
  static const Color inputBackground = Color(0xFFF3F3F5);
  static const Color switchBackground = Color(0xFFCBCED4);
  static const Color ring = Color(0xFFB3B3B3); // oklch(0.708 0 0) ≈

  // ─── Sidebar Colors ──────────────────────────────────────────────────────
  static const Color sidebar = Color(0xFFFAFAFA); // oklch(0.985 0 0)
  static const Color sidebarForeground = Color(0xFF0A0A0A);
  static const Color sidebarPrimary = Color(0xFF030213);
  static const Color sidebarPrimaryForeground = Color(0xFFFAFAFA);
  static const Color sidebarAccent = Color(0xFFF7F7F7); // oklch(0.97 0 0)
  static const Color sidebarAccentForeground = Color(
    0xFF1A1A1A,
  ); // oklch(0.205 0 0)
  static const Color sidebarBorder = Color(0xFFEBEBEB); // oklch(0.922 0 0)
  static const Color sidebarRing = Color(0xFFB3B3B3);

  // ─── Semantic Status Colors ──────────────────────────────────────────────
  // Success
  static const Color successBackground = Color(0xFFF0FDF4); // green-50
  static const Color successText = Color(0xFF166534); // green-800
  static const Color successBorder = Color(0xFFBBF7D0); // green-200

  // Info
  static const Color infoBackground = Color(0xFFEFF6FF); // blue-50
  static const Color infoText = Color(0xFF1E40AF); // blue-800
  static const Color infoBorder = Color(0xFFBFDBFE); // blue-200

  // Warning
  static const Color warningBackground = Color(0xFFFFFBEB); // amber-50
  static const Color warningText = Color(0xFF78350F); // amber-900
  static const Color warningBorder = Color(0xFFFDE68A); // amber-200

  // Error / Expired
  static const Color errorBackground = Color(0xFFFEF2F2); // red-50 (expired)
  static const Color errorText = Color(0xFF991B1B); // red-800
  static const Color errorBorder = Color(0xFFFECACA); // red-200

  // Completed
  static const Color completedBackground = Color(0xFFEFF6FF); // blue-50
  static const Color completedText = Color(0xFF1E40AF); // blue-800
  static const Color completedBorder = Color(0xFFBFDBFE); // blue-200

  // ─── Neutral Grays ───────────────────────────────────────────────────────
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray900 = Color(0xFF111827);

  // ─── Dark Mode Overrides (for reference / ThemeData dark) ────────────────
  static const Color darkBackground = Color(0xFF0A0A0A); // oklch(0.145 0 0)
  static const Color darkForeground = Color(0xFFFAFAFA); // oklch(0.985 0 0)
  static const Color darkCard = Color(0xFF0A0A0A);
  static const Color darkBorder = Color(0xFF2E2E2E); // oklch(0.269 0 0)
  static const Color darkMuted = Color(0xFF2E2E2E);
  static const Color darkMutedForeground = Color(
    0xFFB3B3B3,
  ); // oklch(0.708 0 0)
  static const Color darkRing = Color(0xFF6E6E6E); // oklch(0.439 0 0)
  static const Color darkDestructive = Color(
    0xFF7F1D1D,
  ); // oklch(0.396 0.141 25.723) approx
}
