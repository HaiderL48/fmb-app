import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../apis/api_manager.dart';
import '../../services/auth_token_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/push_topic_service.dart';
import '../../models/user_model.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Persists login session (user/admin flags in SharedPreferences, tokens in secure storage).
class UserDataProvider with ChangeNotifier {
  static const _keyUser = 'fmb_user';
  static const _keyToken = 'fmb_token';
  static const _keyIsAdmin = 'fmb_is_admin';

  UserModel? _user;
  bool _isAdmin = false;
  bool _isLoaded = false;
  bool _isLoggingOut = false;
  String _token = '';

  UserModel? get user => _user;
  bool get isAdmin => _isAdmin;
  bool get isLoggedIn => _user != null || _isAdmin;
  bool get isLoaded => _isLoaded;
  bool get isLoggingOut => _isLoggingOut;
  String get token => _token;

  /// Sync in-memory + SharedPreferences token after [ApiManager] silent refresh.
  void applyRefreshedAccessToken(String accessToken) {
    if (accessToken.isEmpty) return;
    _token = accessToken;
    notifyListeners();
  }

  // ── Load from SharedPreferences on app start ──────────────────────────────
  Future<void> loadAsync() async {
    if (_isLoaded) return;
    final prefs = await SharedPreferences.getInstance();

    final userJson = prefs.getString(_keyUser);
    if (userJson != null) {
      try {
        _user = UserModel.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
      } catch (_) {
        await prefs.remove(_keyUser);
      }
    }

    _token = await AuthTokenService.instance.getAccessToken();
    if (_token.isEmpty) {
      _token = prefs.getString(_keyToken) ?? '';
    }
    _isAdmin = prefs.getBool(_keyIsAdmin) ?? false;
    _isLoaded = true;
    notifyListeners();
  }

  // ── Save app user + token ─────────────────────────────────────────────────
  Future<void> saveUser(
    UserModel user, {
    String token = '',
    String refreshToken = '',
  }) async {
    await PushNotificationService.instance.clearDeliveredNotifications();
    _user = user;
    _token = token;
    _isAdmin = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    await prefs.setBool(_keyIsAdmin, false);
    await AuthTokenService.instance.saveTokens(
      accessToken: token,
      refreshToken: refreshToken,
    );

    // Subscribe logged-in app users to broadcast notifications.
    await PushTopicService.instance.subscribeAllUsersTopic();
  }

  // ── Save admin + token ────────────────────────────────────────────────────
  Future<void> saveAdmin({
    String token = '',
    String refreshToken = '',
  }) async {
    await PushNotificationService.instance.clearDeliveredNotifications();
    _user = null;
    _token = token;
    _isAdmin = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);
    await prefs.setBool(_keyIsAdmin, true);
    await AuthTokenService.instance.saveTokens(
      accessToken: token,
      refreshToken: refreshToken,
    );

    // Keep admin sessions aligned with app-wide broadcast topic delivery.
    await PushTopicService.instance.subscribeAllUsersTopic();
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> clearUser() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    notifyListeners();

    try {
      await ApiManager.logout();
    } catch (_) {}

    try {
      await PushNotificationService.instance.clearDeliveredNotifications();
      _user = null;
      _token = '';
      _isAdmin = false;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUser);
      await prefs.remove(_keyToken);
      await prefs.remove(_keyIsAdmin);
      await AuthTokenService.instance.clearTokens();

      // Best-effort cleanup on logout; failures are logged by the service only.
      await PushTopicService.instance.unsubscribeAllUsersTopic();
    } finally {
      _isLoggingOut = false;
      notifyListeners();
    }
  }

  /// Reloads the signed-in app user from `GET /users/:id` and persists to
  /// SharedPreferences (e.g. distributor assigned after login).
  Future<bool> refreshUserFromServer() async {
    if (_user == null || _token.isEmpty || _isAdmin) return false;
    try {
      final fresh = await ApiManager.getUser(token: _token, userId: _user!.id);
      _user = fresh;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUser, jsonEncode(fresh.toJson()));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Sync Push Meta ────────────────────────────────────────────────────────
  Future<void> syncPushMeta() async {
    if (!isLoggedIn || _token.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final fcmToken = await messaging.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;

      final info = await _resolveAppVersion();
      final platform = _resolvePlatform();

      await ApiManager.updatePushMeta(
        accessToken: _token,
        fcmToken: fcmToken,
        platform: platform,
        appVersion: info,
      );
    } catch (_) {}
  }

  String _resolvePlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'mobile';
  }

  Future<String> _resolveAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }
}
