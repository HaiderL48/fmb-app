import 'package:flutter/material.dart';
import 'colors.dart';

/// Border radius constants matching CSS.css --radius variables
class AppRadius {
  AppRadius._();

  static const double base = 10.0; // --radius: 0.625rem = 10px
  static const double sm = 6.0; // calc(0.625rem - 4px)
  static const double md = 8.0; // calc(0.625rem - 2px)
  static const double lg = 10.0; // 0.625rem
  static const double xl = 14.0; // calc(0.625rem + 4px)

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(999));
}

/// Spacing constants matching Tailwind scale used in STYLE_GUIDE.md
class AppSpacing {
  AppSpacing._();

  static const double s1 = 4.0; // gap-1
  static const double s2 = 8.0; // gap-2 / m-2
  static const double s3 = 12.0; // gap-3 / px-3
  static const double s4 = 16.0; // gap-4 / px-4
  static const double s5 = 20.0; // pt-5
  static const double s6 = 24.0; // gap-6 / px-6 / pb-6
  static const double s8 = 32.0; // h-8
  static const double s9 = 36.0; // h-9
  static const double s10 = 40.0; // h-10 / w-10 icon container
  static const double s12 = 48.0; // h-12 custom button
}

/// Icon sizes matching STYLE_GUIDE.md
class AppIconSize {
  AppIconSize._();

  static const double sm = 16.0; // w-4 h-4
  static const double md = 20.0; // w-5 h-5 (standard)
  static const double lg = 24.0; // w-6 h-6
  static const double xl = 40.0; // w-10 h-10 (icon container)
}

/// Text styles — context-independent static styles.
/// For context-aware (ScreenUtil) styles, extend as needed.
class AppTextStyle {
  AppTextStyle._();

  // ─── Headings ─────────────────────────────────────────────────────────────
  static const TextStyle h1 = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.foreground,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.foreground,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.foreground,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.foreground,
  );

  // ─── Body ─────────────────────────────────────────────────────────────────
  static const TextStyle bodyBase = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.foreground,
  );

  static const TextStyle bodySm = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.foreground,
  );

  static const TextStyle bodyXs = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.gray500,
  );

  // ─── Label / Button ───────────────────────────────────────────────────────
  static const TextStyle label = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.foreground,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  // ─── FMB-specific ─────────────────────────────────────────────────────────

  /// White text on teal background (e.g. card headers)
  static const TextStyle onPrimary = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.primaryForeground,
  );

  /// Gold text on teal background (e.g. primary buttons)
  static const TextStyle fmbButtonLabel = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.fmbAccent,
  );

  /// Muted helper text
  static const TextStyle muted = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.mutedForeground,
  );

  /// Stat card label (xs gray)
  static const TextStyle statLabel = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    color: AppColors.gray500,
  );

  /// Stat card value (sm bold)
  static const TextStyle statValue = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w700,
    color: AppColors.foreground,
  );
}

/// Box shadow presets matching Tailwind shadow-* utilities
class AppShadow {
  AppShadow._();

  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0D000000), // ~5% black
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x1A000000), // ~10% black
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 25, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> xxl = [
    BoxShadow(
      color: Color(0x26000000), // ~15% black
      blurRadius: 50,
      offset: Offset(0, 25),
    ),
    BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 10)),
  ];
}

/// Gradient presets matching STYLE_GUIDE.md
class AppGradient {
  AppGradient._();

  /// Primary page background gradient
  static const LinearGradient primaryBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.fmbPrimary, AppColors.fmbPrimaryDark],
  );

  /// Card gradient (teal)
  static const LinearGradient cardTeal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.fmbPrimary, AppColors.fmbPrimaryDark],
  );

  /// Menu / neutral gradient
  static const LinearGradient neutralCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)], // gray-50 → gray-100
  );
}
