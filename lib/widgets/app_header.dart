import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../constants/colors.dart';
import '../constants/images.dart';
import '../constants/svg.dart';
import '../providers/auth/user_data_provider.dart';
import '../providers/notifications_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/support/support_screen.dart';

double _rw(
  BuildContext context,
  double value, {
  double min = 0,
  double max = double.infinity,
}) => (value * MediaQuery.sizeOf(context).width / 390).clamp(min, max);

double _rh(
  BuildContext context,
  double value, {
  double min = 0,
  double max = double.infinity,
}) => (value * MediaQuery.sizeOf(context).height / 844).clamp(min, max);

double _sp(BuildContext context, double size) =>
    (size * MediaQuery.textScalerOf(context).scale(1)).clamp(
      size * 0.8,
      size * 1.2,
    );

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle = 'Food Package Subscription',
    this.leadingIcon,
    this.onLeadingPressed,
    this.showSupport = true,
    this.showNotifications = true,
    this.showLogout = true,
    this.extraActions = const [],
  });

  final String title;
  final String subtitle;
  final IconData? leadingIcon;
  final VoidCallback? onLeadingPressed;
  final bool showSupport;
  final bool showNotifications;
  final bool showLogout;
  final List<Widget> extraActions;

  Future<void> _logout(BuildContext context) async {
    Provider.of<NotificationsProvider>(
      context,
      listen: false,
    ).clearForSessionChange();
    await Provider.of<UserDataProvider>(context, listen: false).clearUser();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _openNotifications(BuildContext context) async {
    await Provider.of<NotificationsProvider>(
      context,
      listen: false,
    ).markLatestAsSeen();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final iconSz = _rw(context, 22, min: 18, max: 26);
    final isLoggingOut = context.watch<UserDataProvider>().isLoggingOut;
    final hasUnseenNotification =
        showNotifications &&
        context.watch<NotificationsProvider>().hasUnseenLatest;

    return Material(
      color: AppColors.fmbPrimary,
      child: Padding(
        padding: EdgeInsets.only(
          top: top + _rh(context, 8, min: 6),
          left: _rw(context, 16, min: 12),
          right: _rw(context, 8, min: 6),
          bottom: _rh(context, 12, min: 8),
        ),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              IconButton(
                onPressed:
                    onLeadingPressed ?? () => Navigator.maybePop(context),
                padding: EdgeInsets.all(_rw(context, 8, min: 6)),
                constraints: const BoxConstraints(),
                icon: Icon(
                  leadingIcon,
                  color: AppColors.fmbAccent,
                  size: iconSz,
                ),
              ),
              SizedBox(width: _rw(context, 4, min: 2)),
            ],
            Image.asset(
              AppImages.logo,
              height: _rh(context, 36, min: 28, max: 44),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => SizedBox(
                width: _rh(context, 36, min: 28),
                height: _rh(context, 36, min: 28),
              ),
            ),
            SizedBox(width: _rw(context, 10, min: 8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.fmbAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: _sp(context, 15),
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.fmbAccent.withValues(alpha: 0.75),
                      fontSize: _sp(context, 11),
                    ),
                  ),
                ],
              ),
            ),
            if (showSupport)
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupportScreen()),
                  );
                },
                padding: EdgeInsets.all(_rw(context, 8, min: 6)),
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.fmbAccent,
                  size: iconSz,
                ),
              ),
            if (showNotifications)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () => _openNotifications(context),
                    padding: EdgeInsets.all(_rw(context, 8, min: 6)),
                    constraints: const BoxConstraints(),
                    icon: SvgPicture.asset(
                      AppSvg.notificationBell,
                      width: iconSz,
                      height: iconSz,
                      colorFilter: const ColorFilter.mode(
                        AppColors.fmbAccent,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  if (hasUnseenNotification)
                    Positioned(
                      top: _rh(context, 6, min: 4),
                      right: _rw(context, 6, min: 4),
                      child: Container(
                        width: _rw(context, 8, min: 6),
                        height: _rw(context, 8, min: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.destructive,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ...extraActions,
            if (showLogout)
              IconButton(
                onPressed: isLoggingOut ? null : () => _logout(context),
                padding: EdgeInsets.all(_rw(context, 8, min: 6)),
                constraints: const BoxConstraints(),
                icon: isLoggingOut
                    ? SizedBox(
                        width: iconSz,
                        height: iconSz,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.fmbAccent,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.logout_rounded,
                        color: AppColors.fmbAccent,
                        size: iconSz,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
