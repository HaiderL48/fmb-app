import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../apis/api_manager.dart';
import '../../models/user_model.dart';

/// Handles login form state and calls the real POST /auth/login endpoint.
/// Session persistence is done by the screen via UserDataProvider.
class LoginProvider with ChangeNotifier {
  // ─── Controllers ──────────────────────────────────────────────────────────
  final TextEditingController itsController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // ─── State ────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get obscurePassword => _obscurePassword;
  String? get errorMessage => _errorMessage;

  // ─── Validation ───────────────────────────────────────────────────────────
  String? _itsError;
  String? _passwordError;

  String? get itsError => _itsError;
  String? get passwordError => _passwordError;

  bool _validate() {
    _itsError = null;
    _passwordError = null;

    if (itsController.text.trim().isEmpty) {
      _itsError = 'ITS Number is required';
    }
    if (passwordController.text.isEmpty) {
      _passwordError = 'Password is required';
    }

    notifyListeners();
    return _itsError == null && _passwordError == null;
  }

  // ─── Toggle password visibility ───────────────────────────────────────────
  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  // ─── Login ────────────────────────────────────────────────────────────────
  /// Calls POST /auth/login with client = "mobile".
  /// On success calls [onSuccess] with:
  ///   - A [LoginResult] containing the [UserModel] + [accessToken]
  /// The caller (screen) handles persistence + navigation.
  Future<bool> login({
    required void Function(LoginResult result) onSuccess,
  }) async {
    _errorMessage = null;
    if (!_validate()) return false;

    _setLoading(true);

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final fcmToken = await _resolveFcmTokenWithRetry(messaging);

      final platform = _resolvePlatform();
      final appVersion = await _resolveAppVersion();
      log('LOGIN META ::: $fcmToken $platform $appVersion');
      final response = await ApiManager.login(
        itsNumber: itsController.text.trim(),
        password: passwordController.text,
        client: 'mobile',
        fcmToken: fcmToken,
        platform: platform,
        appVersion: appVersion,
      );

      _setLoading(false);
      /* debugPrint(
        '[LoginProvider] Login SUCCESS — userType: ${response.user.userType} — token sent: ${fcmToken.isNotEmpty}',
      );*/
      onSuccess(
        LoginResult(
          user: response.user,
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
          isAdmin: response.user.userType == 'ADMIN',
        ),
      );

      // If token wasn't ready during login, sync it once it arrives.
      if (fcmToken.isEmpty) {
        _schedulePushMetaSync(
          messaging: messaging,
          accessToken: response.accessToken,
          platform: platform,
          appVersion: appVersion,
        );
      }
      return true;
    } on ApiException catch (e) {
      // debugPrint('[LoginProvider] ApiException: ${e.message}');
      _errorMessage = e.message;
      _setLoading(false);
      return false;
    } on SocketException {
      _errorMessage = 'No internet connection. Please check your network.';
      _setLoading(false);
      return false;
    } on TimeoutException {
      _errorMessage = 'Request timed out. Please try again.';
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _setLoading(false);
      return false;
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
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

  Future<String> _resolveFcmTokenWithRetry(FirebaseMessaging messaging) async {
    if (kIsWeb) {
      // Web push requires a valid firebase-messaging-sw.js; do not block login.
      return '';
    }
    for (int attempt = 1; attempt <= 3; attempt++) {
      String token = '';
      try {
        token = (await messaging.getToken()) ?? '';
      } on FirebaseException {
        /* debugPrint(
          '[LoginProvider] Web/FCM getToken failed on attempt $attempt: '
          '${e.code} ${e.message ?? ''}',
        );*/
        return '';
      } catch (_) {
        // debugPrint('[LoginProvider] FCM getToken unexpected error: $e');
        return '';
      }
      if (token.isNotEmpty) return token;
      if (attempt < 3) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return '';
  }

  void _schedulePushMetaSync({
    required FirebaseMessaging messaging,
    required String accessToken,
    required String platform,
    required String appVersion,
  }) {
    messaging.onTokenRefresh.first
        .then((token) async {
          if (token.isEmpty) return;
          try {
            await ApiManager.updatePushMeta(
              accessToken: accessToken,
              fcmToken: token,
              platform: platform,
              appVersion: appVersion,
            );
            // debugPrint('[LoginProvider] Late FCM token synced successfully.');
          } catch (e) {
            //  debugPrint('[LoginProvider] Late FCM token sync failed: $e');
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    itsController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

/// Carries the login result back to the screen.
class LoginResult {
  final UserModel user;
  final String accessToken;
  final String refreshToken;
  final bool isAdmin;

  const LoginResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.isAdmin,
  });
}
