import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/colors.dart';
import '../constants/svg.dart';

/// Logical shell tabs (index order matches [BottomBar._tabs] when Zabihat is shown).
enum AppTab { home, packages, zabihat, payment, settings }

/// FMB bottom navigation bar.
///
/// Usage — inside the home page scaffold:
/// ```dart
/// Scaffold(
///   body: _screens[_currentTab],
///   bottomNavigationBar: BottomBar(
///     currentTab: _currentTab,
///     onChange: (tab) => setState(() => _currentTab = tab),
///   ),
/// )
/// ```
class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.currentTab,
    required this.onChange,
    this.showZabihat = true,
  });

  final int currentTab;
  final ValueChanged<int> onChange;
  final bool showZabihat;

  // ── Tab definitions ────────────────────────────────────────────────────────
  List<_TabItem> _tabs() => [
    const _TabItem.svg(
      label: 'Home',
      activeSvg: AppSvg.activeHome,
      inactiveSvg: null, // no inactive-home in assets — use active tinted gray
    ),
    const _TabItem.svg(
      label: 'Packages',
      activeSvg: AppSvg.activePackages,
      inactiveSvg: AppSvg.packages,
    ),
    if (showZabihat)
      const _TabItem.svg(
        label: 'Zabihat',
        activeSvg: AppSvg.activeCart,
        inactiveSvg: AppSvg.cart,
      ),
    const _TabItem.svg(
      label: 'Payments',
      activeSvg: AppSvg.activeWallet,
      inactiveSvg: AppSvg.wallet,
    ),
    const _TabItem.icon(
      label: 'Settings',
      icon: Icons.settings_rounded,
      inactiveIcon: Icons.settings_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.fmbPrimary,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(tabs.length, (index) {
              return Expanded(
                child: _BottomBarItem(
                  tab: tabs[index],
                  isActive: currentTab == index,
                  onTap: () => onChange(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Single tab item ────────────────────────────────────────────────────────────

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final _TabItem tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.fmbAccent
        : AppColors.fmbAccent.withValues(alpha: 0.45);

    final Widget iconWidget;
    if (tab.icon != null) {
      final ic = isActive ? tab.icon! : (tab.inactiveIcon ?? tab.icon!);
      iconWidget = Icon(ic, size: 24, color: color);
    } else {
      final svgPath = isActive
          ? tab.activeSvg!
          : (tab.inactiveSvg ?? tab.activeSvg!);
      iconWidget = SvgPicture.asset(
        svgPath,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: color,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data class ─────────────────────────────────────────────────────────────────

class _TabItem {
  const _TabItem.svg({
    required this.label,
    required this.activeSvg,
    this.inactiveSvg,
  }) : icon = null,
       inactiveIcon = null;

  const _TabItem.icon({
    required this.label,
    required this.icon,
    this.inactiveIcon,
  }) : activeSvg = null,
       inactiveSvg = null;

  final String label;
  final String? activeSvg;
  final String? inactiveSvg;
  final IconData? icon;
  final IconData? inactiveIcon;
}
