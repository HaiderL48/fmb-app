import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../components/bottom_bar.dart';
import '../../models/user_model.dart';
import '../../providers/auth/user_data_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/zabihat_provider.dart';
import '../../services/push_notification_service.dart';
import '../../services/push_topic_service.dart';
import '../../widgets/main_shell_back_scope.dart';
import 'tabs/home_tab.dart';
import 'tabs/packages_tab.dart';
import 'tabs/zabihat_tab.dart';
import 'tabs/payment_tab.dart';
import 'tabs/profile_tab.dart';

class HomePage extends StatefulWidget {
  final UserModel? user;
  final int initialTab;

  const HomePage({super.key, this.user, this.initialTab = 0});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int currentTab;
  List<Widget> _screens({
    required bool showZabihat,
    required int activeIndex,
  }) {
    final base = <Widget>[
      HomeTab(user: widget.user, handleShellBack: activeIndex == 0),
      PackagesTab(handleShellBack: activeIndex == 1),
      if (showZabihat) ZabihatTab(handleShellBack: activeIndex == 2),
      PaymentTab(handleShellBack: activeIndex == (showZabihat ? 3 : 2)),
    ];
    final settingsTabIndex = base.length;
    return [
      ...base,
      ProfileTab(
        user: widget.user,
        handleShellBack: activeIndex == settingsTabIndex,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    currentTab = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      final zabihat = Provider.of<ZabihatProvider>(context, listen: false);
      final notifications = Provider.of<NotificationsProvider>(context, listen: false);
      final token = userData.token;
      // Keep notification permissions healthy (Android/iOS) on cold start.
      await PushNotificationService.instance.ensureNotificationPermissions(force: true);
      // Ensures FCM topic `all_users` is subscribed after cold start / app update (idempotent).
      if (token.isNotEmpty && userData.user != null) {
        await PushTopicService.instance.subscribeAllUsersTopic();
      }
      if (!mounted) return;
      zabihat.loadOfferings(token: token);
      notifications.load(token: token);
    });
  }

  Future<void> _confirmAndMaybeExit() async {
    if (!mounted) return;
    // Do not prompt when a pushed screen (notifications, support, etc.) is
    // still on the stack — back should dismiss that route first.
    final nav = Navigator.of(context);
    if (nav.canPop()) return;

    final rootNav = Navigator.of(context, rootNavigator: true);
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (!mounted || shouldExit != true) return;
    if (rootNav.canPop()) {
      rootNav.pop();
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainShellBackScope(
      confirmExit: _confirmAndMaybeExit,
      child: Consumer<ZabihatProvider>(
        builder: (context, zabihatProvider, _) {
          final showZabihat =
              !zabihatProvider.hasLoadedOfferingsOnce ||
              zabihatProvider.errorMessage != null ||
              zabihatProvider.offerings.isNotEmpty;

          final tabCount = 4 + (showZabihat ? 1 : 0);
          final safeCurrentTab = currentTab >= tabCount
              ? tabCount - 1
              : currentTab;

          final screens = _screens(
            showZabihat: showZabihat,
            activeIndex: safeCurrentTab,
          );

          if (safeCurrentTab != currentTab) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => currentTab = safeCurrentTab);
            });
          }

          return Scaffold(
            extendBody: true,
            resizeToAvoidBottomInset: false,
            // IndexedStack keeps all tab widgets alive — no rebuild on tab switch
            body: IndexedStack(index: safeCurrentTab, children: screens),
            bottomNavigationBar: BottomBar(
              currentTab: safeCurrentTab,
              showZabihat: showZabihat,
              onChange: (index) {
                setState(() {
                  currentTab = index;
                });
              },
            ),
          );
        },
      ),
    );
  }
}
