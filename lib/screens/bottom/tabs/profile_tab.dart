import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../constants/colors.dart';
import '../../../constants/styles.dart';
import '../../../constants/svg.dart';
import '../../../models/takhmin_history_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth/user_data_provider.dart';
import '../../../providers/home_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../utils/misri_year.dart';
import '../../../utils/app_snackbar.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_logo_loader.dart';
import '../../../widgets/main_shell_back_scope.dart';
import '../../../widgets/menu_feedback_section.dart';

// ─── Responsive helpers ────────────────────────────────────────────────────────
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

enum _ProfileScreen {
  hub,
  myInformation,
  distributor,
  menuFeedback,
  takhminHistory,
}

// ─── ProfileTab ───────────────────────────────────────────────────────────────

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, this.user, this.handleShellBack = true});
  final UserModel? user;

  /// When false (e.g. another bottom tab is visible), do not register a blocking
  /// [PopScope] — [IndexedStack] keeps this widget mounted and would otherwise
  /// steal the system back key from the rest of the shell.
  final bool handleShellBack;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _hasLoadedOnce = false;
  _ProfileScreen _screen = _ProfileScreen.hub;

  Future<void> _refreshProfileData() async {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    provider.initFromUser(userData.user ?? widget.user);
    try {
      await provider.loadTakhminHistory(token: userData.token);
    } finally {
      if (mounted && !_hasLoadedOnce) {
        setState(() => _hasLoadedOnce = true);
      }
    }
  }

  Future<void> _onPullRefresh() async {
    await _refreshProfileData();
    if (!mounted) return;
    if (_screen == _ProfileScreen.menuFeedback) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      if (userData.token.isEmpty) return;
      await Provider.of<HomeProvider>(
        context,
        listen: false,
      ).loadHomeData(userData.user ?? widget.user, token: userData.token);
    }
  }

  void _openMenuFeedback() {
    setState(() => _screen = _ProfileScreen.menuFeedback);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      if (userData.token.isEmpty) return;
      final home = Provider.of<HomeProvider>(context, listen: false);
      if (home.weeklyMenu.isEmpty) {
        unawaited(
          home.loadHomeData(
            userData.user ?? widget.user,
            token: userData.token,
          ),
        );
      }
    });
  }

  void _popToHub() => setState(() => _screen = _ProfileScreen.hub);

  ({String title, String subtitle, bool showBack}) _headerForScreen() {
    switch (_screen) {
      case _ProfileScreen.hub:
        return (
          title: 'Settings',
          subtitle: 'Account & preferences',
          showBack: false,
        );
      case _ProfileScreen.myInformation:
        return (
          title: 'Profile',
          subtitle: 'Name, contacts & password',
          showBack: true,
        );
      case _ProfileScreen.distributor:
        return (
          title: 'Distributor',
          subtitle: 'Your assigned delivery contact',
          showBack: true,
        );
      case _ProfileScreen.menuFeedback:
        return (
          title: 'Menu Feedback',
          subtitle: 'Rate this week’s menus',
          showBack: true,
        );
      case _ProfileScreen.takhminHistory:
        return (
          title: 'Takhmin history',
          subtitle: 'Past amounts & status',
          showBack: true,
        );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfileData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        // Profile saved snackbar
        if (provider.isSaved) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppSnackBar.success(context, 'Profile updated successfully!');
            provider.clearSaved();
          });
        }
        // Password saved snackbar
        if (provider.isPasswordSaved) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppSnackBar.success(context, 'Password updated successfully!');
            provider.clearPasswordSaved();
          });
        }

        final h = _headerForScreen();

        final scaffold = Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              AppHeader(
                title: h.title,
                subtitle: h.subtitle,
                leadingIcon: h.showBack
                    ? Icons.arrow_back_ios_new_rounded
                    : null,
                onLeadingPressed: h.showBack ? _popToHub : null,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onPullRefresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      _rw(context, 16, min: 12),
                      _rh(context, 16, min: 12),
                      _rw(context, 16, min: 12),
                      100,
                    ),
                    child: _buildScreenBody(context, provider),
                  ),
                ),
              ),
            ],
          ),
        );

        if (!widget.handleShellBack) {
          return scaffold;
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (didPop) return;
            if (_screen != _ProfileScreen.hub) {
              _popToHub();
            } else {
              unawaited(MainShellBackScope.delegateExitConfirmation(context));
            }
          },
          child: scaffold,
        );
      },
    );
  }

  Widget _buildScreenBody(BuildContext context, ProfileProvider provider) {
    switch (_screen) {
      case _ProfileScreen.hub:
        return Column(
          children: [
            _ProfileHeroCard(user: widget.user),
            SizedBox(height: _rh(context, 20, min: 14)),
            _SettingsHubTile(
              icon: Icons.person_outline_rounded,
              title: 'Profile',
              subtitle: 'Personal details and change password',
              onTap: () =>
                  setState(() => _screen = _ProfileScreen.myInformation),
            ),
            _SettingsHubTile(
              icon: Icons.local_shipping_outlined,
              title: 'Distributor',
              subtitle: 'Name and mobile of your assigned distributor',
              onTap: () => setState(() => _screen = _ProfileScreen.distributor),
            ),
            _SettingsHubTile(
              icon: Icons.restaurant_menu_rounded,
              title: 'Menu Feedback',
              subtitle: 'Rate dishes for each day this week',
              onTap: _openMenuFeedback,
            ),
            _SettingsHubTile(
              icon: Icons.history_rounded,
              title: 'Takhmin History',
              subtitle: 'View past takhmin records',
              onTap: () =>
                  setState(() => _screen = _ProfileScreen.takhminHistory),
            ),
          ],
        );
      case _ProfileScreen.myInformation:
        return Column(
          children: [
            _PersonalInfoCard(provider: provider, user: widget.user),
            SizedBox(height: _rh(context, 16, min: 12)),
            _ChangePasswordCard(
              provider: provider,
              currentPassword: widget.user?.password ?? '',
            ),
          ],
        );
      case _ProfileScreen.distributor:
        return _DistributorInfoPanel(fallbackUser: widget.user);
      case _ProfileScreen.menuFeedback:
        final token = context.watch<UserDataProvider>().token;
        return _MenuFeedbackPanel(token: token);
      case _ProfileScreen.takhminHistory:
        return _TakhminHistoryCard(
          provider: provider,
          showInitialLoader: !_hasLoadedOnce,
        );
    }
  }
}

class _SettingsHubTile extends StatelessWidget {
  const _SettingsHubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: _rh(context, 12, min: 8)),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: _rw(context, 16, min: 12),
            vertical: _rh(context, 14, min: 10),
          ),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(_rw(context, 16, min: 12)),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadow.sm,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.fmbPrimary,
                size: _rw(context, 24, min: 20),
              ),
              SizedBox(width: _rw(context, 14, min: 10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: _sp(context, 15),
                        color: AppColors.foreground,
                      ),
                    ),
                    SizedBox(height: _rh(context, 4, min: 2)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: _sp(context, 13),
                        color: AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.gray400,
                size: _rw(context, 26, min: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistributorInfoPanel extends StatefulWidget {
  const _DistributorInfoPanel({this.fallbackUser});

  final UserModel? fallbackUser;

  @override
  State<_DistributorInfoPanel> createState() => _DistributorInfoPanelState();
}

class _DistributorInfoPanelState extends State<_DistributorInfoPanel> {
  bool _refreshing = true;
  bool _refreshFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pullLatest());
  }

  Future<void> _pullLatest() async {
    final ud = Provider.of<UserDataProvider>(context, listen: false);
    if (!mounted) return;
    if (ud.user == null || ud.token.isEmpty) {
      setState(() {
        _refreshing = false;
        _refreshFailed = true;
      });
      return;
    }
    setState(() {
      _refreshing = true;
      _refreshFailed = false;
    });
    final ok = await ud.refreshUserFromServer();
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _refreshFailed = !ok;
    });
  }

  Future<void> _launchTel(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    final forDial = trimmed.replaceAll(RegExp(r'[\s\-.()]'), '');
    if (forDial.isEmpty) return;
    final uri = Uri.parse('tel:$forDial');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        AppSnackBar.warning(
          context,
          'Could not open the phone app.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.warning(
        context,
        'Could not open the phone app.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_refreshing) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: _rh(context, 40, min: 28)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _rw(context, 28, min: 24),
                height: _rw(context, 28, min: 24),
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.fmbPrimary,
                ),
              ),
              SizedBox(height: _rh(context, 14, min: 10)),
              Text(
                'Loading distributor…',
                style: TextStyle(
                  fontSize: _sp(context, 14),
                  color: AppColors.gray600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<UserDataProvider>(
      builder: (context, userData, _) {
        final user = userData.user ?? widget.fallbackUser;
        final d = user?.distributor;
        final pad = _rw(context, 16, min: 12);

        Widget row(String label, String value, IconData icon) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.gray700,
                  fontWeight: FontWeight.w500,
                  fontSize: _sp(context, 13),
                ),
              ),
              SizedBox(height: _rh(context, 6, min: 4)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: _rw(context, 12, min: 10),
                  vertical: _rh(context, 12, min: 10),
                ),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(_rw(context, 8, min: 6)),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: _rw(context, 18, min: 14),
                      color: AppColors.gray400,
                    ),
                    SizedBox(width: _rw(context, 8, min: 6)),
                    Expanded(
                      child: Text(
                        value.isNotEmpty ? value : '—',
                        style: TextStyle(
                          fontSize: _sp(context, 15),
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final noDist = d == null || (d.name.isEmpty && d.mobileNumber.isEmpty);

        final pKd = user?.distributorPriceKd;
        final assignedPriceText = pKd == null
            ? ''
            : (pKd == pKd.roundToDouble()
                  ? '${pKd.toStringAsFixed(0)} KD'
                  : '${pKd.toStringAsFixed(2)} KD');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_refreshFailed) ...[
              Container(
                padding: EdgeInsets.all(_rw(context, 12, min: 10)),
                decoration: BoxDecoration(
                  color: AppColors.warningBackground,
                  borderRadius: BorderRadius.circular(_rw(context, 10, min: 8)),
                  border: Border.all(color: AppColors.warningBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off_outlined,
                      color: AppColors.warningText,
                      size: _rw(context, 22, min: 18),
                    ),
                    SizedBox(width: _rw(context, 10, min: 8)),
                    Expanded(
                      child: Text(
                        'Could not reach the server to update your profile. '
                        'Pull down to refresh Settings, or try again later.',
                        style: TextStyle(
                          fontSize: _sp(context, 12),
                          color: AppColors.gray700,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: _rh(context, 12, min: 8)),
            ],
            if (noDist)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(pad),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(
                    _rw(context, 16, min: 12),
                  ),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadow.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.fmbPrimary,
                          size: _rw(context, 22, min: 18),
                        ),
                        SizedBox(width: _rw(context, 8, min: 6)),
                        Expanded(
                          child: Text(
                            'No distributor assigned',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: _sp(context, 15),
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _pullLatest,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                    SizedBox(height: _rh(context, 10, min: 8)),
                    Text(
                      'Your account does not have a distributor on file yet. '
                      'If one was assigned recently, tap Retry above.',
                      style: TextStyle(
                        fontSize: _sp(context, 13),
                        color: AppColors.gray600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(pad),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(
                    _rw(context, 16, min: 12),
                  ),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadow.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SvgPicture.asset(
                          AppSvg.profile,
                          width: _rw(context, 18, min: 14),
                          height: _rw(context, 18, min: 14),
                          colorFilter: const ColorFilter.mode(
                            AppColors.fmbPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                        SizedBox(width: _rw(context, 8, min: 6)),
                        Expanded(
                          child: Text(
                            'Your Distributor',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: _sp(context, 15),
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: _rh(context, 16, min: 12)),
                    row('Name', d.name, Icons.badge_outlined),
                    SizedBox(height: _rh(context, 14, min: 10)),
                    row('Mobile Number', d.mobileNumber, Icons.phone_outlined),
                    if (d.mobileNumber.trim().isNotEmpty) ...[
                      SizedBox(height: _rh(context, 12, min: 8)),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => unawaited(_launchTel(d.mobileNumber)),
                          icon: Icon(
                            Icons.call_rounded,
                            size: _rw(context, 20, min: 18),
                          ),
                          label: Text(
                            'Call now',
                            style: TextStyle(
                              fontSize: _sp(context, 15),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.fmbPrimary,
                            foregroundColor: AppColors.fmbAccent,
                            padding: EdgeInsets.symmetric(
                              vertical: _rh(context, 12, min: 10),
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.mdAll,
                            ),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: _rh(context, 14, min: 10)),
                    row(
                      'Assigned Price',
                      assignedPriceText,
                      Icons.payments_outlined,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MenuFeedbackPanel extends StatelessWidget {
  const _MenuFeedbackPanel({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, home, _) {
        if (home.isLoading && home.weeklyMenu.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: _rh(context, 48, min: 32)),
            child: const Center(child: AppLogoLoader()),
          );
        }
        if (home.weeklyMenu.isEmpty) {
          return Text(
            'No menu is available for this week yet. Pull to refresh after the menu is published.',
            style: TextStyle(
              fontSize: _sp(context, 14),
              color: AppColors.gray600,
              height: 1.35,
            ),
          );
        }

        final menu = home.selectedMenu;
        final pad = _rw(context, 16, min: 12);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(pad),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(_rw(context, 16, min: 12)),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadow.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        AppSvg.calendar,
                        width: _rw(context, 18, min: 14),
                        height: _rw(context, 18, min: 14),
                        colorFilter: const ColorFilter.mode(
                          AppColors.fmbPrimary,
                          BlendMode.srcIn,
                        ),
                      ),
                      SizedBox(width: _rw(context, 8, min: 6)),
                      Text(
                        "This Week's Menu",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: _sp(context, 15),
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: _rh(context, 12, min: 8)),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(home.weeklyMenu.length, (i) {
                        final isActive = home.selectedMenuIndex == i;
                        final day = home.weeklyMenu[i].dayLabel;
                        return Padding(
                          padding: EdgeInsets.only(
                            right: _rw(context, 8, min: 6),
                          ),
                          child: GestureDetector(
                            onTap: () => home.selectMenuDay(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(
                                horizontal: _rw(context, 12, min: 10),
                                vertical: _rh(context, 8, min: 6),
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.fmbPrimary
                                    : AppColors.gray100,
                                borderRadius: AppRadius.lgAll,
                              ),
                              child: Text(
                                day,
                                style: TextStyle(
                                  color: isActive
                                      ? AppColors.fmbAccent
                                      : AppColors.gray700,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  fontSize: _sp(context, 13),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  if (menu != null) ...[
                    SizedBox(height: _rh(context, 12, min: 8)),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(_rw(context, 12, min: 10)),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: AppRadius.lgAll,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Meal",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: _sp(context, 14),
                              color: AppColors.foreground,
                            ),
                          ),
                          SizedBox(height: _rh(context, 8, min: 4)),
                          ...menu.items.map(
                            (item) => Padding(
                              padding: EdgeInsets.only(
                                bottom: _rh(context, 4, min: 2),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: _rw(context, 6, min: 5),
                                    height: _rw(context, 6, min: 5),
                                    margin: EdgeInsets.only(
                                      right: _rw(context, 8, min: 6),
                                      top: 1,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: AppColors.fmbPrimary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      item,
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
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (menu != null) ...[
              SizedBox(height: _rh(context, 16, min: 12)),
              MenuFeedbackSection(provider: home, menu: menu, token: token),
            ],
          ],
        );
      },
    );
  }
}

// ── Profile hero card (scrollable) ────────────────────────────────────────────

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({this.user});
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: _rh(context, 24, min: 18),
        horizontal: _rw(context, 16, min: 12),
      ),
      decoration: BoxDecoration(
        gradient: AppGradient.cardTeal,
        borderRadius: BorderRadius.circular(_rw(context, 16, min: 12)),
        boxShadow: AppShadow.md,
      ),
      child: Column(
        children: [
          // White avatar circle
          Container(
            width: _rw(context, 72, min: 56, max: 88),
            height: _rw(context, 72, min: 56, max: 88),
            decoration: const BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                AppSvg.activeProfile,
                width: _rw(context, 36, min: 28, max: 44),
                height: _rw(context, 36, min: 28, max: 44),
                colorFilter: const ColorFilter.mode(
                  AppColors.fmbPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          SizedBox(height: _rh(context, 12, min: 8)),
          Text(
            user?.fullName ?? '—',
            style: TextStyle(
              color: AppColors.fmbAccent,
              fontWeight: FontWeight.w700,
              fontSize: _sp(context, 20),
            ),
          ),
          SizedBox(height: _rh(context, 4, min: 2)),
          Text(
            'ITS: ${user?.itsNumber ?? '—'}',
            style: TextStyle(
              color: AppColors.fmbAccent.withValues(alpha: 0.8),
              fontSize: _sp(context, 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Personal info card ─────────────────────────────────────────────────────────

class _PersonalInfoCard extends StatelessWidget {
  const _PersonalInfoCard({required this.provider, this.user});
  final ProfileProvider provider;
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final pad = _rw(context, 16, min: 12);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_rw(context, 16, min: 12)),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              SvgPicture.asset(
                AppSvg.profile,
                width: _rw(context, 18, min: 14),
                height: _rw(context, 18, min: 14),
                colorFilter: const ColorFilter.mode(
                  AppColors.fmbPrimary,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: _rw(context, 8, min: 6)),
              Text(
                'Personal Information',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: _sp(context, 15),
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          SizedBox(height: _rh(context, 16, min: 12)),

          // Thali + Sabil row (read-only)
          Row(
            children: [
              Expanded(
                child: _ReadOnlyField(
                  label: 'Thali Number',
                  value: user?.thaliNumber ?? '—',
                  icon: Icons.grid_view_rounded,
                ),
              ),
              SizedBox(width: _rw(context, 12, min: 8)),
              Expanded(
                child: _ReadOnlyField(
                  label: 'Sabil Number',
                  value: user?.sabilNumber ?? '—',
                  icon: Icons.tag_rounded,
                ),
              ),
            ],
          ),
          SizedBox(height: _rh(context, 14, min: 10)),

          // Full Name
          _FieldLabel('Full Name'),
          SizedBox(height: _rh(context, 6, min: 4)),
          _EditableField(
            controller: provider.fullNameController,
            hint: 'Full name',
            icon: Icons.person_outline_rounded,
          ),
          SizedBox(height: _rh(context, 12, min: 8)),

          // Email
          _FieldLabel('Email Address'),
          SizedBox(height: _rh(context, 6, min: 4)),
          _EditableField(
            controller: provider.emailController,
            hint: 'Email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: _rh(context, 12, min: 8)),

          // Contact
          _FieldLabel('Contact Number'),
          SizedBox(height: _rh(context, 6, min: 4)),
          _EditableField(
            controller: provider.contactController,
            hint: 'Contact number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: _rh(context, 12, min: 8)),

          // Address
          _FieldLabel('Address'),
          SizedBox(height: _rh(context, 6, min: 4)),
          _EditableField(
            controller: provider.addressController,
            hint: 'Address',
            icon: Icons.location_on_outlined,
            maxLines: 2,
          ),

          // Error
          if (provider.errorMessage != null) ...[
            SizedBox(height: _rh(context, 8, min: 6)),
            Text(
              provider.errorMessage!,
              style: TextStyle(
                color: AppColors.destructive,
                fontSize: _sp(context, 12),
              ),
            ),
          ],

          SizedBox(height: _rh(context, 16, min: 12)),

          // Save button
          _ActionButton(
            label: 'Save Changes',
            icon: Icons.save_outlined,
            isLoading: provider.isLoading,
            backgroundColor: AppColors.fmbPrimary,
            foregroundColor: AppColors.fmbAccent,
            onTap: () {
              final userData = Provider.of<UserDataProvider>(
                context,
                listen: false,
              );
              provider.saveChanges(
                userId: user?.id ?? '',
                token: userData.token,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Change password card ───────────────────────────────────────────────────────

class _ChangePasswordCard extends StatelessWidget {
  const _ChangePasswordCard({
    required this.provider,
    required this.currentPassword,
  });
  final ProfileProvider provider;
  final String currentPassword;

  @override
  Widget build(BuildContext context) {
    final pad = _rw(context, 16, min: 12);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_rw(context, 16, min: 12)),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              SvgPicture.asset(
                AppSvg.lock,
                width: _rw(context, 18, min: 14),
                height: _rw(context, 18, min: 14),
                colorFilter: const ColorFilter.mode(
                  AppColors.fmbPrimary,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: _rw(context, 8, min: 6)),
              Text(
                'Change Password',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: _sp(context, 15),
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          SizedBox(height: _rh(context, 16, min: 12)),

          // Current password
          _FieldLabel('Current Password'),
          SizedBox(height: _rh(context, 6, min: 4)),
          _PasswordField(
            controller: provider.currentPwController,
            hint: '',
            obscure: provider.obscureCurrent,
            onToggle: provider.toggleCurrent,
          ),
          SizedBox(height: _rh(context, 12, min: 8)),

          // New password
          _FieldLabel('New Password'),
          SizedBox(height: _rh(context, 6, min: 4)),
          _PasswordField(
            controller: provider.newPwController,
            hint: '',
            obscure: provider.obscureNew,
            onToggle: provider.toggleNew,
          ),
          SizedBox(height: _rh(context, 12, min: 8)),

          // Confirm password
          _FieldLabel('Confirm New Password'),
          SizedBox(height: _rh(context, 6, min: 4)),
          _PasswordField(
            controller: provider.confirmPwController,
            hint: '',
            obscure: provider.obscureConfirm,
            onToggle: provider.toggleConfirm,
          ),

          // Error
          if (provider.pwErrorMessage != null) ...[
            SizedBox(height: _rh(context, 8, min: 6)),
            Text(
              provider.pwErrorMessage!,
              style: TextStyle(
                color: AppColors.destructive,
                fontSize: _sp(context, 12),
              ),
            ),
          ],

          SizedBox(height: _rh(context, 16, min: 12)),

          // Update button
          _ActionButton(
            label: 'Update Password',
            icon: Icons.lock_outline_rounded,
            isLoading: provider.isLoading,
            backgroundColor: AppColors.fmbPrimary,
            foregroundColor: AppColors.fmbAccent,
            onTap: () {
              final userData = Provider.of<UserDataProvider>(
                context,
                listen: false,
              );
              provider.updatePassword(
                userId: userData.user?.id ?? '',
                token: userData.token,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.gray700,
        fontWeight: FontWeight.w500,
        fontSize: _sp(context, 13),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        SizedBox(height: _rh(context, 6, min: 4)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: _rw(context, 12, min: 10),
            vertical: _rh(context, 10, min: 8),
          ),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(_rw(context, 8, min: 6)),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: _rw(context, 16, min: 12),
                color: AppColors.gray400,
              ),
              SizedBox(width: _rw(context, 6, min: 4)),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: _sp(context, 13),
                    color: AppColors.gray600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _rh(context, 3, min: 2)),
        Text(
          'Read-only',
          style: TextStyle(
            color: AppColors.gray400,
            fontSize: _sp(context, 10),
          ),
        ),
      ],
    );
  }
}

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(_rw(context, 8, min: 6)),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textInputAction: maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.done,
        onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        style: TextStyle(
          fontSize: _sp(context, 14),
          color: AppColors.foreground,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.gray400,
            fontSize: _sp(context, 14),
          ),
          prefixIcon: Icon(
            icon,
            size: _rw(context, 18, min: 14),
            color: AppColors.gray400,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: _rw(context, 12, min: 10),
            vertical: _rh(context, 10, min: 8),
          ),
          isDense: true,
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
  });
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(_rw(context, 8, min: 6)),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        style: TextStyle(
          fontSize: _sp(context, 14),
          color: AppColors.foreground,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.gray400,
            fontSize: _sp(context, 14),
          ),
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            size: _rw(context, 18, min: 14),
            color: AppColors.gray400,
          ),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: _rw(context, 18, min: 14),
              color: AppColors.gray400,
            ),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: _rw(context, 12, min: 10),
            vertical: _rh(context, 10, min: 8),
          ),
          isDense: true,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    this.backgroundColor,
    this.foregroundColor,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.fmbPrimary;
    final fg = foregroundColor ?? AppColors.fmbAccent;
    return SizedBox(
      width: double.infinity,
      height: _rh(context, 48, min: 40, max: 56),
      child: Material(
        color: isLoading ? bg.withValues(alpha: 0.6) : bg,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: AppRadius.mdAll,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: _rw(context, 20, min: 16),
                    height: _rw(context, 20, min: 16),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.fmbAccent),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: fg, size: _rw(context, 18, min: 14)),
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

// ── Takhmin History card ───────────────────────────────────────────────────────

class _TakhminHistoryCard extends StatelessWidget {
  const _TakhminHistoryCard({
    required this.provider,
    required this.showInitialLoader,
  });
  final ProfileProvider provider;
  final bool showInitialLoader;

  @override
  Widget build(BuildContext context) {
    final pad = _rw(context, 16, min: 12);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_rw(context, 16, min: 12)),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              SvgPicture.asset(
                AppSvg.activePackages,
                width: _rw(context, 18, min: 14),
                height: _rw(context, 18, min: 14),
                colorFilter: const ColorFilter.mode(
                  AppColors.fmbPrimary,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: _rw(context, 8, min: 6)),
              Text(
                'Takhmin History',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: _sp(context, 15),
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          SizedBox(height: _rh(context, 14, min: 10)),

          if (provider.isHistoryLoading && showInitialLoader)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: AppLogoLoader(size: 56),
              ),
            )
          else if (provider.historyErrorMessage != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(_rw(context, 10, min: 8)),
              decoration: BoxDecoration(
                color: AppColors.errorBackground,
                borderRadius: BorderRadius.circular(_rw(context, 10, min: 8)),
                border: Border.all(color: AppColors.errorBorder),
              ),
              child: Text(
                provider.historyErrorMessage!,
                style: TextStyle(
                  color: AppColors.errorText,
                  fontSize: _sp(context, 12),
                ),
              ),
            )
          else if (provider.takhminHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(_rw(context, 12, min: 10)),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(_rw(context, 10, min: 8)),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'No takhmin history available yet.',
                style: TextStyle(
                  color: AppColors.gray600,
                  fontSize: _sp(context, 13),
                ),
              ),
            )
          else
            ...provider.takhminHistory.map(
              (entry) => Padding(
                padding: EdgeInsets.only(bottom: _rh(context, 12, min: 8)),
                child: _TakhminHistoryEntryCard(entry: entry),
              ),
            ),
        ],
      ),
    );
  }
}

class _TakhminHistoryEntryCard extends StatelessWidget {
  const _TakhminHistoryEntryCard({required this.entry});
  final TakhminHistoryModel entry;

  String get _status => entry.completed ? 'Completed' : 'Pending';
  Color get _statusBg => entry.completed
      ? AppColors.successBackground
      : AppColors.warningBackground;
  Color get _statusFg =>
      entry.completed ? AppColors.successText : AppColors.warningText;

  @override
  Widget build(BuildContext context) {
    final pad = _rw(context, 14, min: 10);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(_rw(context, 12, min: 8)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: name + status badge ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Misri Year ${formatMisriYear(entry.misriYear)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: _sp(context, 15),
                    color: AppColors.foreground,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _rw(context, 10, min: 8),
                  vertical: _rh(context, 3, min: 2),
                ),
                decoration: BoxDecoration(
                  color: _statusBg,
                  borderRadius: BorderRadius.circular(
                    _rw(context, 20, min: 14),
                  ),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    color: _statusFg,
                    fontWeight: FontWeight.w600,
                    fontSize: _sp(context, 11),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: _rh(context, 6, min: 4)),

          // ── Row 2: amount ─────────────────────────────────────────────────
          Text(
            '${entry.takhminAmountKd.toStringAsFixed(0)} KD',
            style: TextStyle(
              color: AppColors.fmbPrimary,
              fontWeight: FontWeight.w700,
              fontSize: _sp(context, 18),
            ),
          ),
          SizedBox(height: _rh(context, 10, min: 8)),

          // ── Divider ───────────────────────────────────────────────────────
          Divider(color: AppColors.border, height: 1),
          SizedBox(height: _rh(context, 10, min: 8)),

          // ── Row 3: updated date ───────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: _rw(context, 14, min: 11),
                color: AppColors.gray500,
              ),
              SizedBox(width: _rw(context, 6, min: 4)),
              Text(
                entry.updatedAt == null
                    ? 'Updated date unavailable'
                    : 'Updated ${entry.updatedAt!.day}/${entry.updatedAt!.month}/${entry.updatedAt!.year}',
                style: TextStyle(
                  color: AppColors.gray600,
                  fontSize: _sp(context, 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
