import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/colors.dart';
import '../../../constants/styles.dart';
import '../../../models/package_model.dart';
import '../../../providers/auth/user_data_provider.dart';
import '../../../providers/packages_provider.dart';
import '../../../utils/app_snackbar.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_logo_loader.dart';
import '../../../widgets/tab_shell_pop_scope.dart';
import '../../support/support_screen.dart';

// ─── Responsive helpers (same pattern as home_tab) ────────────────────────────
double _rw(
  BuildContext ctx,
  double v, {
  double min = 0,
  double max = double.infinity,
}) => (v * MediaQuery.sizeOf(ctx).width / 390).clamp(min, max);
double _rh(
  BuildContext ctx,
  double v, {
  double min = 0,
  double max = double.infinity,
}) => (v * MediaQuery.sizeOf(ctx).height / 844).clamp(min, max);
double _sp(BuildContext ctx, double s) =>
    (s * MediaQuery.textScalerOf(ctx).scale(1)).clamp(s * 0.8, s * 1.2);

// ─── PackagesTab ──────────────────────────────────────────────────────────────

class PackagesTab extends StatefulWidget {
  const PackagesTab({super.key, this.handleShellBack = false});

  /// When true, this tab is visible in the bottom shell; intercept system back.
  final bool handleShellBack;

  @override
  State<PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends State<PackagesTab> {
  bool _hasLoadedOnce = false;

  Future<void> _load() async {
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    try {
      await Provider.of<PackagesProvider>(
        context,
        listen: false,
      ).loadPackages(userData.user, token: userData.token);
    } finally {
      if (mounted && !_hasLoadedOnce) {
        setState(() => _hasLoadedOnce = true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PackagesProvider>(
      builder: (context, provider, _) {
        return TabShellPopScope(
          handleShellBack: widget.handleShellBack,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                const AppHeader(title: 'Packages'),
                Expanded(
                  child: provider.isLoading && !_hasLoadedOnce
                      ? const Center(child: AppLogoLoader())
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _PackagesList(provider: provider),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Packages list ──────────────────────────────────────────────────────────────

class _PackagesList extends StatelessWidget {
  const _PackagesList({required this.provider});
  final PackagesProvider provider;

  @override
  Widget build(BuildContext context) {
    final h = _rw(context, 16, min: 12);
    final v = _rh(context, 16, min: 12);

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(h, v, h, 100),
      itemCount: provider.packages.length + 1, // +1 for help card
      separatorBuilder: (_, __) => SizedBox(height: _rh(context, 16, min: 12)),
      itemBuilder: (context, i) {
        // Last item → help card
        if (i == provider.packages.length) {
          return const _HelpCard();
        }
        final pkg = provider.packages[i];
        final isSelectingThis =
            provider.isLoading && provider.selectingPackageId == pkg.id;
        return _PackageCard(
          package: pkg,
          isCurrentPlan: pkg.id == provider.currentPackageId,
          isPopular: pkg.tier == PackageTier.premium,
          onSelect: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SupportScreen()),
            );
          },
          isLoading: isSelectingThis,
        );
      },
    );
  }
}

// ── Package card ───────────────────────────────────────────────────────────────

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.isCurrentPlan,
    required this.isPopular,
    required this.onSelect,
    required this.isLoading,
  });

  final PackageModel package;
  final bool isCurrentPlan;
  final bool isPopular;
  final VoidCallback onSelect;
  final bool isLoading;

  // Tier-specific accent color for the price
  Color get _priceColor {
    switch (package.tier) {
      case PackageTier.premium:
        return AppColors.fmbPrimary;
      case PackageTier.family:
        return AppColors.fmbPrimary;
      default:
        return AppColors.fmbPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = _rw(context, 16, min: 12);
    final borderColor = isCurrentPlan ? AppColors.fmbPrimary : AppColors.border;
    final borderWidth = isCurrentPlan ? 2.0 : 1.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Card ────────────────────────────────────────────────────────────
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(_rw(context, 16, min: 12)),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SupportScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(_rw(context, 16, min: 12)),
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: AppShadow.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ───────────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Name + tier badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: _sp(context, 18),
                            color: AppColors.foreground,
                          ),
                        ),
                        SizedBox(height: _rh(context, 4, min: 2)),
                        _TierBadge(tier: package.tier),
                      ],
                    ),
                  ),
                  SizedBox(width: _rw(context, 8, min: 6)),
                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: package.priceKd.toStringAsFixed(0),
                              style: TextStyle(
                                color: _priceColor,
                                fontWeight: FontWeight.w800,
                                fontSize: _sp(context, 26),
                              ),
                            ),
                            TextSpan(
                              text: 'KD',
                              style: TextStyle(
                                color: _priceColor,
                                fontWeight: FontWeight.w700,
                                fontSize: _sp(context, 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'per ${package.validity}',
                        style: TextStyle(
                          color: AppColors.gray500,
                          fontSize: _sp(context, 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

                  SizedBox(height: _rh(context, 16, min: 12)),

                  // ── Features ─────────────────────────────────────────────────
                  Text(
                    'INCLUDES:',
                    style: TextStyle(
                      color: AppColors.gray500,
                      fontSize: _sp(context, 10),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: _rh(context, 8, min: 6)),
                  ...package.features.map(
                (f) => Padding(
                  padding: EdgeInsets.only(bottom: _rh(context, 5, min: 3)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        color: AppColors.fmbPrimary,
                        size: _rw(context, 16, min: 13),
                      ),
                      SizedBox(width: _rw(context, 6, min: 4)),
                      Flexible(
                        child: Text(
                          f,
                          style: TextStyle(
                            color: AppColors.gray700,
                            fontSize: _sp(context, 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: _rh(context, 16, min: 12)),

              // ── Installment options ───────────────────────────────────────
              Text(
                'INSTALLMENT OPTIONS:',
                style: TextStyle(
                  color: AppColors.gray500,
                  fontSize: _sp(context, 10),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: _rh(context, 8, min: 6)),
              Wrap(
                spacing: _rw(context, 8, min: 6),
                runSpacing: _rh(context, 6, min: 4),
                children: package.installmentOptions.map((amt) {
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _rw(context, 14, min: 10),
                      vertical: _rh(context, 6, min: 4),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(
                        _rw(context, 20, min: 14),
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${amt.toStringAsFixed(0)} KD',
                      style: TextStyle(
                        fontSize: _sp(context, 13),
                        fontWeight: FontWeight.w500,
                        color: AppColors.foreground,
                      ),
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: _rh(context, 16, min: 12)),

              // ── Select button ─────────────────────────────────────────────
              _SelectButton(
                package: package,
                isCurrentPlan: isCurrentPlan,
                isLoading: isLoading,
                onSelect: onSelect,
              ),
                ],
              ),
            ),
          ),
        ),

        // ── Popular badge (top-right) ────────────────────────────────────────
        if (isPopular)
          Positioned(
            top: -_rh(context, 10, min: 8),
            right: _rw(context, 16, min: 12),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: _rw(context, 10, min: 8),
                vertical: _rh(context, 4, min: 3),
              ),
              decoration: BoxDecoration(
                color: AppColors.fmbPrimary,
                borderRadius: BorderRadius.circular(_rw(context, 20, min: 14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: AppColors.fmbAccent,
                    size: _rw(context, 12, min: 10),
                  ),
                  SizedBox(width: _rw(context, 4, min: 2)),
                  Text(
                    'Popular',
                    style: TextStyle(
                      color: AppColors.fmbAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: _sp(context, 11),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Current plan badge (top-left) ────────────────────────────────────
        if (isCurrentPlan)
          Positioned(
            top: -_rh(context, 10, min: 8),
            left: _rw(context, 16, min: 12),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: _rw(context, 10, min: 8),
                vertical: _rh(context, 4, min: 3),
              ),
              decoration: BoxDecoration(
                color: AppColors.successText,
                borderRadius: BorderRadius.circular(_rw(context, 20, min: 14)),
              ),
              child: Text(
                'Current Plan',
                style: TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.w700,
                  fontSize: _sp(context, 11),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Tier badge ─────────────────────────────────────────────────────────────────

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});
  final PackageTier tier;

  Color get _bg {
    switch (tier) {
      case PackageTier.premium:
        return AppColors.fmbPrimary.withValues(alpha: 0.1);
      case PackageTier.family:
        return AppColors.fmbAccent.withValues(alpha: 0.15);
      default:
        return AppColors.gray100;
    }
  }

  Color get _fg {
    switch (tier) {
      case PackageTier.premium:
        return AppColors.fmbPrimary;
      case PackageTier.family:
        return AppColors.fmbAccentDark;
      default:
        return AppColors.gray600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _rw(context, 10, min: 8),
        vertical: _rh(context, 3, min: 2),
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(_rw(context, 6, min: 4)),
      ),
      child: Text(
        tier.label,
        style: TextStyle(
          color: _fg,
          fontWeight: FontWeight.w600,
          fontSize: _sp(context, 12),
        ),
      ),
    );
  }
}

// ── Select button ──────────────────────────────────────────────────────────────

IconData _packageSelectButtonIcon(PackageTier tier, {required bool isCurrentPlan}) {
  if (isCurrentPlan) return Icons.check_circle_outline_rounded;
  switch (tier) {
    case PackageTier.basic:
      return Icons.restaurant_menu_outlined;
    case PackageTier.premium:
      return Icons.star_border_rounded;
    case PackageTier.family:
      return Icons.family_restroom_rounded;
  }
}

class _SelectButton extends StatelessWidget {
  const _SelectButton({
    required this.package,
    required this.isCurrentPlan,
    required this.isLoading,
    required this.onSelect,
  });

  final PackageModel package;
  final bool isCurrentPlan;
  final bool isLoading;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final label = isCurrentPlan
        ? 'Current Plan'
        : 'Select ${package.tier.label}';

    final bg = isCurrentPlan ? AppColors.foreground : AppColors.fmbPrimary;
    final fg = isCurrentPlan ? AppColors.background : AppColors.fmbAccent;

    final icon = _packageSelectButtonIcon(
      package.tier,
      isCurrentPlan: isCurrentPlan,
    );

    return SizedBox(
      width: double.infinity,
      height: _rh(context, 48, min: 40, max: 56),
      child: Material(
        color: isLoading ? bg.withValues(alpha: 0.6) : bg,
        borderRadius: BorderRadius.circular(_rw(context, 10, min: 8)),
        child: InkWell(
          onTap: isLoading ? null : onSelect,
          borderRadius: BorderRadius.circular(_rw(context, 10, min: 8)),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: _rw(context, 20, min: 16),
                    height: _rw(context, 20, min: 16),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(fg),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: fg,
                        size: _rw(context, 18, min: 14),
                      ),
                      SizedBox(width: _rw(context, 8, min: 6)),
                      Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w600,
                          fontSize: _sp(context, 15),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Help card ──────────────────────────────────────────────────────────────────

class _HelpCard extends StatelessWidget {
  const _HelpCard();

  static const _bgColor = Color(0xFFDBEAFE); // blue-100
  static const _textColor = Color(0xFF1E3A5F); // dark navy
  static const _linkColor = Color(0xFF1D4ED8); // blue-700

  @override
  Widget build(BuildContext context) {
    final pad = _rw(context, 16, min: 12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_rw(context, 16, min: 12)),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SupportScreen()),
          );
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(_rw(context, 16, min: 12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Heading
              Text(
                'Need help choosing?',
                style: TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: _sp(context, 16),
                ),
              ),
              SizedBox(height: _rh(context, 8, min: 6)),

              // Body
              Text(
                'Contact our support team for personalized recommendations based on your needs.',
                style: TextStyle(
                  color: _linkColor,
                  fontSize: _sp(context, 13),
                  height: 1.5,
                ),
              ),
              SizedBox(height: _rh(context, 14, min: 10)),

              // Email row
              _ContactRow(icon: Icons.email_outlined, label: 'support@fmb.com'),
              SizedBox(height: _rh(context, 8, min: 6)),

              // Phone row
              _ContactRow(icon: Icons.phone_outlined, label: '+965 1234 5678'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  static const _linkColor = Color(0xFF1D4ED8);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _linkColor, size: _rw(context, 18, min: 14)),
        SizedBox(width: _rw(context, 8, min: 6)),
        Text(
          label,
          style: TextStyle(
            color: _linkColor,
            fontWeight: FontWeight.w500,
            fontSize: _sp(context, 14),
          ),
        ),
      ],
    );
  }
}
