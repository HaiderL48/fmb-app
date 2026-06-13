/// All SVG asset paths.
/// Usage: SvgPicture.asset(AppSvg.home)
///
/// Requires the `flutter_svg` package:
///   flutter_svg: ^2.0.0   (add to pubspec.yaml dependencies)
class AppSvg {
  AppSvg._();

  // ─── Bottom Navigation Icons ──────────────────────────────────────────────

  /// Active (selected) state icons
  static const String activeHome =
      'assets/svg/bottom-navigation-icons/active-home.svg';
  static const String activeCart =
      'assets/svg/bottom-navigation-icons/active-cart.svg';
  static const String activePackages =
      'assets/svg/bottom-navigation-icons/active-packages.svg';
  static const String activeProfile =
      'assets/svg/bottom-navigation-icons/active-profile.svg';
  static const String activeWallet =
      'assets/svg/bottom-navigation-icons/active-wallet.svg';

  /// Inactive (default) state icons
  static const String cart = 'assets/svg/bottom-navigation-icons/cart.svg';
  static const String packages =
      'assets/svg/bottom-navigation-icons/packages.svg';
  static const String profile =
      'assets/svg/bottom-navigation-icons/profile.svg';
  static const String wallet = 'assets/svg/bottom-navigation-icons/wallet.svg';

  // ─── UI Icons ─────────────────────────────────────────────────────────────

  static const String alert = 'assets/svg/ui-icons/alert.svg';
  static const String calendar =
      'assets/svg/ui-icons/celendar.svg'; // note: typo in filename kept intentionally
  static const String key = 'assets/svg/ui-icons/key.svg';
  static const String lock = 'assets/svg/ui-icons/lock.svg';
  static const String markedRead = 'assets/svg/ui-icons/marked-read.svg';
  static const String notificationBell =
      'assets/svg/ui-icons/notifcation-bell.svg'; // note: typo in filename kept intentionally
  static const String package = 'assets/svg/ui-icons/package.svg';
}
