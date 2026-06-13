import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import '../providers/auth/user_data_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/zabihat_provider.dart';
import '../screens/bottom/home_page.dart';
import '../screens/notifications/notifications_screen.dart';
import 'package:provider/provider.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'fmb_notifications',
    'FMB Notifications',
    description: 'Channel for FMB push notifications',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _localNotificationsReady = false;

  bool _initialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;

    await _initLocalNotifications();
    debugPrint('[Push] Local notifications initialized');
    await ensureNotificationPermissions();
    debugPrint('[Push] Permissions checked');
    await _configureForegroundPresentation();
    _listenForegroundMessages();
    _listenTapEvents();
    await _handleInitialMessage();
    debugPrint('[Push] Service initialization complete');
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) =>
            _handleLocalNotificationTap(response.payload),
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
      _localNotificationsReady = true;
    } on MissingPluginException {
      _localNotificationsReady = false;
      /* debugPrint(
        '[Push] Local notifications plugin missing: $e. '
        'Do a full app restart (not hot reload).',
      );*/
    }
  }

  /// Ensures notification permission is requested and re-checked.
  /// Call this on app start and after resume/login to reduce device-specific failures.
  Future<void> ensureNotificationPermissions({bool force = false}) async {
    try {
      // iOS permission (and Android 13+ supported via plugin-specific permission calls).
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      if (force || settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // iOS local notification permission (required to display notifications while foreground).
      await _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      // Android 13+ runtime notification permission.
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (_) {
      // Best-effort; do not block app start.
    }
  }

  Future<void> _configureForegroundPresentation() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Clears delivered local notifications (tray entries) during session changes.
  Future<void> clearDeliveredNotifications() async {
    if (!_localNotificationsReady) return;
    try {
      await _localNotifications.cancelAll();
    } catch (_) {}
  }

  void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('[Push] Foreground message received: ${message.messageId}');
      _logIncomingMessageDiagnostics(message);
      _cacheIncomingMessage(message);
      await _refreshNotificationsFromApi();
      await _showForegroundNotification(message);
    });
  }

  void _listenTapEvents() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      // debugPrint('[Push] Notification opened from background');
      _logIncomingMessageDiagnostics(message);
      _cacheIncomingMessage(message);
      await _refreshNotificationsFromApi();
      _openFromMessageData(message.data);
    });
  }

  Future<void> _handleInitialMessage() async {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial == null) return;
    // debugPrint('[Push] App opened from terminated notification');
    _logIncomingMessageDiagnostics(initial);
    _cacheIncomingMessage(initial);
    await _refreshNotificationsFromApi();
    _openFromMessageData(initial.data);
  }

  void _logIncomingMessageDiagnostics(RemoteMessage message) {
    // Reserved for future device-specific debugging.
    // final type = message.data['type'];
    // final title = message.notification?.title;
    //  debugPrint('[Push] Message diagnostics — type: $type, title: $title');
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_localNotificationsReady) return;
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;

    const androidDetails = AndroidNotificationDetails(
      'fmb_notifications',
      'FMB Notifications',
      channelDescription: 'Channel for FMB push notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_fmb',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      title ?? 'New notification',
      body ?? '',
      details,
      payload: jsonEncode(message.data),
    );
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    if (!_localNotificationsReady) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'fmb_notifications',
        'FMB Notifications',
        channelDescription: 'Channel for FMB push notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_fmb',
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title,
        body,
        details,
        payload: data.isEmpty ? null : jsonEncode(data),
      );
    } catch (_) {}
  }

  void _handleLocalNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) {
      _openNotificationsScreen();
      return;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _openFromMessageData(decoded);
        return;
      }
    } catch (_) {}
    _openNotificationsScreen();
  }

  void _openFromMessageData(Map<String, dynamic> data) {
    final screen = (data['screen'] ?? '').toString().toLowerCase();
    switch (screen) {
      case 'zabihat':
        _openHomeTab(2);
        return;
      case 'menu':
        _openHomeTab(0);
        return;
      case 'packages':
        _openHomeTab(1);
        return;
      case 'takhmin':
        _openPaymentTab();
        return;
      default:
        _openNotificationsScreen();
    }
  }

  void _openHomeTab(int tabIndex) {
    final navigator = _navigatorKey?.currentState;
    final context = _navigatorKey?.currentContext;
    if (navigator == null || context == null) return;
    final user = context.read<UserDataProvider>().user;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => HomePage(user: user, initialTab: tabIndex),
      ),
    );
  }

  /// Payment tab index depends on whether Zabihat is in the bottom bar.
  void _openPaymentTab() {
    final navigator = _navigatorKey?.currentState;
    final context = _navigatorKey?.currentContext;
    if (navigator == null || context == null) return;
    final user = context.read<UserDataProvider>().user;
    var paymentIndex = 3;
    try {
      final zp = context.read<ZabihatProvider>();
      final showZabihat =
          !zp.hasLoadedOfferingsOnce ||
          zp.errorMessage != null ||
          zp.offerings.isNotEmpty;
      paymentIndex = showZabihat ? 3 : 2;
    } catch (_) {}
    navigator.push(
      MaterialPageRoute(
        builder: (_) => HomePage(user: user, initialTab: paymentIndex),
      ),
    );
  }

  Future<void> _refreshNotificationsFromApi() async {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    try {
      final userData = context.read<UserDataProvider>();
      if (userData.token.isEmpty) return;
      await context.read<NotificationsProvider>().load(token: userData.token);
    } catch (_) {}
  }

  void _cacheIncomingMessage(RemoteMessage message) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;
    try {
      final userData = context.read<UserDataProvider>();
      if (userData.token.isEmpty) return;
      context.read<NotificationsProvider>().addFromPush(
        id: message.messageId,
        title: message.notification?.title,
        body: message.notification?.body,
        data: message.data,
      );
    } catch (_) {}
  }

  void _openNotificationsScreen() {
    final navigator = _navigatorKey?.currentState;
    final context = _navigatorKey?.currentContext;
    if (navigator == null) return;

    try {
      context?.read<NotificationsProvider>().markLatestAsSeen();
    } catch (_) {}

    navigator.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }
}
