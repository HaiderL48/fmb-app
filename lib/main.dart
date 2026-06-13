import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'apis/api_manager.dart';
import 'constants/colors.dart';
import 'constants/theme_data.dart';
import 'providers/auth/login_provider.dart';
import 'providers/auth/user_data_provider.dart';
import 'providers/home_provider.dart';
import 'providers/notifications_provider.dart';
import 'providers/packages_provider.dart';
import 'providers/zabihat_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/payments_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/bottom/home_page.dart';
import 'services/push_notification_service.dart';
import 'widgets/app_logo_loader.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

Future<void> _configureFirebaseAndFetchFcmToken() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  if (kIsWeb) {
    // Web login should not depend on firebase-messaging service worker availability.
    // debugPrint('[Push] Web runtime detected; skipping FCM token bootstrap.');
    return;
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Minimal permission flags (alert / badge / sound) — matches Apple-focused setup;
  // extra iOS-only options were omitted to avoid plugin / permission quirks on some devices.
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  // debugPrint(
  //   '[Push] Notification permission status: ${settings.authorizationStatus}',
  // );

  final String? token = await _fetchFcmTokenWithRetry(messaging);
  if (token != null && token.isNotEmpty) {
    debugPrint('FCM Token: $token');
  } else {
    debugPrint('FCM token is null or empty.');
  }
  // debugPrint(b
  //   '[ApiConfig] Active payment verify base: '
  //   '${ApiConstants.paymentUPaymentsVerify('__url_check__')}',
  // );
}

Future<String?> _fetchFcmTokenWithRetry(
  FirebaseMessaging messaging, {
  int maxAttempts = 3,
}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await messaging.getToken();
    } on FirebaseException catch (e) {
      final message = (e.message ?? '').toLowerCase();
      final isServiceUnavailable = message.contains('service_not_available');
      final isLastAttempt = attempt == maxAttempts;
      // debugPrint(
      //   '[Push] getToken attempt $attempt/$maxAttempts failed: '
      //   '${e.code} ${e.message ?? ''}',
      // );
      if (!isServiceUnavailable || isLastAttempt) {
        return null;
      }
      await Future<void>.delayed(Duration(seconds: attempt * 2));
    } catch (e) {
      // debugPrint('[Push] getToken unexpected error: $e');
      return null;
    }
  }
  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureFirebaseAndFetchFcmToken();
  runApp(const FmbApp());
}

class FmbApp extends StatelessWidget {
  const FmbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
        ChangeNotifierProvider(create: (_) => LoginProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
        ChangeNotifierProvider(create: (_) => PackagesProvider()),
        ChangeNotifierProvider(create: (_) => ZabihatProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => PaymentsProvider()),
      ],
      child: Builder(
        builder: (context) {
          ApiManager.onAccessTokenRefreshed = (newAccessToken) {
            Provider.of<UserDataProvider>(
              context,
              listen: false,
            ).applyRefreshedAccessToken(newAccessToken);
          };
          ApiManager.setSessionExpiredHandler(() async {
            final userDataProvider = Provider.of<UserDataProvider>(
              context,
              listen: false,
            );
            Provider.of<NotificationsProvider>(
              context,
              listen: false,
            ).clearForSessionChange();
            await userDataProvider.clearUser();
            final navigator = appNavigatorKey.currentState;
            if (navigator == null) return;
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            );
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            PushNotificationService.instance.initialize(
              navigatorKey: appNavigatorKey,
            );
          });
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: 'TMK FMB',
            debugShowCheckedModeBanner: false,
            theme: appTheme,
            darkTheme: appDarkTheme,
            themeMode: ThemeMode.light,
            builder: (context, child) {
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  final current = FocusManager.instance.primaryFocus;
                  if (current != null && !current.hasPrimaryFocus) {
                    current.unfocus();
                  }
                },
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const _SplashGate(),
          );
        },
      ),
    );
  }
}

/// Reads SharedPreferences once on startup, then routes to the correct screen.
/// Shows a teal splash while loading — no flicker to login.
class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final userDataProvider = Provider.of<UserDataProvider>(
      context,
      listen: false,
    );
    await userDataProvider.loadAsync();
    await userDataProvider.syncPushMeta();

    if (!mounted) return;

    if (userDataProvider.isLoggedIn && userDataProvider.user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePage(user: userDataProvider.user),
        ),
      );
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Teal splash screen while checking session
    return Scaffold(
      backgroundColor: AppColors.fmbPrimary,
      body: const Center(child: AppLogoLoader()),
    );
  }
}
