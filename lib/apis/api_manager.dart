import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/login_response_model.dart';
import '../models/menu_model.dart';
import '../models/mumin_due_model.dart';
import '../models/package_model.dart';
import '../models/payment_model.dart';
import '../models/user_model.dart';
import '../models/zabihat_model.dart';
import '../models/thali_pause_model.dart';
import '../services/auth_token_service.dart';

/// Central HTTP layer for all FMB API calls.
/// Every method throws [ApiException] on non-2xx responses.
class ApiManager {
  ApiManager._();

  static const Duration _timeout = Duration(seconds: 30);
  static Future<String?>? _refreshInFlight;
  static Future<void> Function()? _onSessionExpired;

  /// Called after a successful silent refresh so [UserDataProvider.token] matches storage.
  static void Function(String newAccessToken)? onAccessTokenRefreshed;

  static void setSessionExpiredHandler(Future<void> Function() handler) {
    _onSessionExpired = handler;
  }

  /// Parses access/refresh tokens from login or refresh responses (top-level or `data` object).
  static Map<String, String> _parseTokenPairFromAuthBody(
    Map<String, dynamic> body,
  ) {
    var root = body;
    final nested = body['data'];
    if (nested is Map<String, dynamic>) {
      root = nested;
    }
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = root[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return '';
    }

    return {
      'accessToken': pick(['accessToken', 'access_token', 'token']),
      'refreshToken': pick(['refreshToken', 'refresh_token']),
    };
  }

  // ─── Shared headers ────────────────────────────────────────────────────────
  static Map<String, String> _jsonHeaders({String? token}) => {
    HttpHeaders.contentTypeHeader: 'application/json',
    HttpHeaders.acceptHeader: 'application/json',
    if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
  };

  /// Ngrok free tier may return an HTML interstitial without this header.
  static const Map<String, String> _ngrokSkipBrowserWarning = {
    'ngrok-skip-browser-warning': 'true',
  };

  static Map<String, String>? _ngrokExtraIfNeeded(Uri uri) =>
      uri.host.contains('ngrok') ? _ngrokSkipBrowserWarning : null;

  // ─── Logger ────────────────────────────────────────────────────────────────
  static void _log(String title, http.Response res) {
    // dev.log(
    //   '[$title]\n'
    //   '  URL    : ${res.request?.url}\n'
    //   '  STATUS : ${res.statusCode}\n'
    //   '  BODY   : ${res.body}',
    //   name: 'ApiManager',
    // );
  }

  static void _logRequest(String title, String url, {Object? body}) {
    // dev.log(
    //   '[$title → REQUEST]\n'
    //   '  URL  : $url\n'
    //   '  BODY : ${body != null ? jsonEncode(body) : '—'}',
    //   name: 'ApiManager',
    // );
  }

  static Map<String, dynamic> _decodedBody(http.Response res) {
    if (res.body.trim().isEmpty) return <String, dynamic>{};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static List<Map<String, dynamic>> _decodedDataList(http.Response res) {
    final body = _decodedBody(res);
    final list = body['data'] as List<dynamic>? ?? const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Map<String, dynamic> _decodedDataMap(http.Response res) {
    final body = _decodedBody(res);
    return body['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
  }

  static void _logPaymentRequest(String title, String url, {Object? body}) {
    // dev.log(
    //   '[HTTP][$title][request] url=$url body=${bodySummary ?? 'none'}',
    //   name: 'UPayments',
    // );
  }

  static void _logPaymentResponse(String title, http.Response res) {
    // dev.log(
    //   '[HTTP][$title][response] status=${res.statusCode} url=${res.request?.url} data=$summary',
    //   name: 'UPayments',
    // );
  }

  static Future<http.Response> _authorizedGet({
    required Uri uri,
    required String token,
    Map<String, String>? extraHeaders,
  }) {
    return _authorizedRequest(
      initialToken: token,
      request: (bearer) => http
          .get(
            uri,
            headers: {
              ..._jsonHeaders(token: bearer),
              ...?extraHeaders,
            },
          )
          .timeout(_timeout),
    );
  }

  static Future<http.Response> _authorizedPost({
    required Uri uri,
    required String token,
    Object? body,
    Map<String, String>? extraHeaders,
  }) {
    return _authorizedRequest(
      initialToken: token,
      request: (bearer) => http
          .post(
            uri,
            headers: {
              ..._jsonHeaders(token: bearer),
              ...?extraHeaders,
            },
            body: body,
          )
          .timeout(_timeout),
    );
  }

  static Future<http.Response> _authorizedPatch({
    required Uri uri,
    required String token,
    Object? body,
    Map<String, String>? extraHeaders,
  }) {
    return _authorizedRequest(
      initialToken: token,
      request: (bearer) => http
          .patch(
            uri,
            headers: {
              ..._jsonHeaders(token: bearer),
              ...?extraHeaders,
            },
            body: body,
          )
          .timeout(_timeout),
    );
  }

  static Future<http.Response> _authorizedPut({
    required Uri uri,
    required String token,
    Object? body,
    Map<String, String>? extraHeaders,
  }) {
    return _authorizedRequest(
      initialToken: token,
      request: (bearer) => http
          .put(
            uri,
            headers: {
              ..._jsonHeaders(token: bearer),
              ...?extraHeaders,
            },
            body: body,
          )
          .timeout(_timeout),
    );
  }

  static Future<http.Response> _authorizedDelete({
    required Uri uri,
    required String token,
  }) {
    return _authorizedRequest(
      initialToken: token,
      request: (bearer) => http
          .delete(uri, headers: _jsonHeaders(token: bearer))
          .timeout(_timeout),
    );
  }

  static Future<http.Response> _authorizedMultipartPost({
    required Uri uri,
    required String token,
    required Map<String, String> fields,
    required List<File> attachments,
  }) {
    return _authorizedRequest(
      initialToken: token,
      request: (bearer) async {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll({
          HttpHeaders.acceptHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'Bearer $bearer',
        });
        request.fields.addAll(fields);
        for (final file in attachments) {
          request.files.add(
            await http.MultipartFile.fromPath('attachments', file.path),
          );
        }
        final streamed = await request.send().timeout(_timeout);
        return http.Response.fromStream(streamed);
      },
    );
  }

  static Future<http.Response> _authorizedRequest({
    required String initialToken,
    required Future<http.Response> Function(String bearerToken) request,
  }) async {
    final persistedAccess = await AuthTokenService.instance.getAccessToken();
    final tokenToUse = persistedAccess.isNotEmpty
        ? persistedAccess
        : initialToken;

    var res = await request(tokenToUse);
    if (res.statusCode != 401) return res;

    final refreshedToken = await _refreshAccessTokenWithLock();
    if (refreshedToken == null || refreshedToken.isEmpty) {
      // Check if refresh token was actually cleared (truly expired/invalid session).
      // If it's still present, the refresh failed due to a transient network issue
      // or server 5xx error. We should NOT trigger a logout in that case.
      final stillHasRefresh = await AuthTokenService.instance.getRefreshToken();
      if (stillHasRefresh.isEmpty) {
        if (_onSessionExpired != null) {
          await _onSessionExpired!.call();
        }
      }
      return res;
    }

    res = await request(refreshedToken);
    return res;
  }

  static Future<String?> _refreshAccessTokenWithLock() async {
    final currentRefresh = await AuthTokenService.instance.getRefreshToken();
    if (currentRefresh.isEmpty) return null;

    if (_refreshInFlight != null) {
      return _refreshInFlight;
    }

    _refreshInFlight = () async {
      try {
        final res = await http
            .post(
              Uri.parse(ApiConstants.refresh),
              headers: _jsonHeaders(),
              body: jsonEncode({'refreshToken': currentRefresh}),
            )
            .timeout(_timeout);

        _checkStatus(res);
        final body = _decodedBody(res);
        final tokens = _parseTokenPairFromAuthBody(body);
        final newAccessToken = tokens['accessToken'] ?? '';
        final newRefreshToken = tokens['refreshToken'] ?? '';
        if (newAccessToken.isEmpty) {
          // dev.log(
          //   '[ApiManager] Refresh response missing accessToken. Body keys: ${body.keys.toList()}',
          //   name: 'ApiManager',
          // );
          return null;
        }

        await AuthTokenService.instance.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken.isNotEmpty ? newRefreshToken : null,
        );
        onAccessTokenRefreshed?.call(newAccessToken);
        return newAccessToken;
      } on ApiException catch (e) {
        // If the server explicitly returns 400, 401, or 403, the refresh token is indeed invalid/expired.
        if (e.statusCode == 400 || e.statusCode == 401 || e.statusCode == 403) {
          await AuthTokenService.instance.clearTokens();
        }
        return null;
      } catch (_) {
        // Transient network drop or 5xx server error. Do NOT clear tokens.
        return null;
      } finally {
        _refreshInFlight = null;
      }
    }();

    return _refreshInFlight;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HEALTH
  // ══════════════════════════════════════════════════════════════════════════

  /// GET /health
  static Future<Map<String, dynamic>> pingHealthRoot() async {
    final url = '${ApiConstants.baseUrl.replaceAll('/api/v1', '')}/health';
    _logRequest('PING HEALTH ROOT', url);

    final res = await http
        .get(Uri.parse(url), headers: _jsonHeaders())
        .timeout(_timeout);

    _log('PING HEALTH ROOT', res);
    _checkStatus(res);
    return _decodedBody(res);
  }

  /// GET /api/v1/health
  static Future<Map<String, dynamic>> pingHealthV1() async {
    final url = '${ApiConstants.baseUrl}/health';
    _logRequest('PING HEALTH V1', url);

    final res = await http
        .get(Uri.parse(url), headers: _jsonHeaders())
        .timeout(_timeout);

    _log('PING HEALTH V1', res);
    _checkStatus(res);
    return _decodedBody(res);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTH
  // ══════════════════════════════════════════════════════════════════════════

  /// POST /auth/login
  static Future<LoginResponseModel> login({
    required String itsNumber,
    required String password,
    String client = 'mobile',
    String? fcmToken,
    String? platform,
    String? appVersion,
  }) async {
    final payload = {
      'itsNumber': itsNumber,
      'password': password,
      'client': client,
      // Always send mobile metadata keys so backend can rely on request shape.
      'fcmToken': fcmToken ?? '',
      'platform': platform ?? '',
      'appVersion': appVersion ?? '',
    };
    _logRequest('LOGIN', ApiConstants.login, body: payload);

    final res = await http
        .post(
          Uri.parse(ApiConstants.login),
          headers: _jsonHeaders(),
          body: jsonEncode(payload),
        )
        .timeout(_timeout);

    _log('LOGIN', res);
    _checkStatus(res);
    final parsed = LoginResponseModel.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
    await AuthTokenService.instance.saveTokens(
      accessToken: parsed.accessToken,
      refreshToken: parsed.refreshToken,
    );
    return parsed;
  }

  /// POST /auth/logout
  static Future<void> logout() async {
    final refreshToken = await AuthTokenService.instance.getRefreshToken();
    if (refreshToken.isEmpty) return;

    try {
      final res = await http
          .post(
            Uri.parse(ApiConstants.logout),
            headers: _jsonHeaders(),
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_timeout);
      _checkStatus(res);
    } catch (_) {
      // ignore logout errors; local token cleanup happens anyway.
    }
  }

  /// PATCH /auth/push-meta
  /// Best-effort device metadata sync after login when FCM token arrives late.
  static Future<void> updatePushMeta({
    required String accessToken,
    required String fcmToken,
    required String platform,
    required String appVersion,
  }) async {
    final payload = {
      'fcmToken': fcmToken,
      'platform': platform,
      'appVersion': appVersion,
    };
    _logRequest('UPDATE PUSH META', ApiConstants.authPushMeta, body: payload);

    final res = await _authorizedPatch(
      uri: Uri.parse(ApiConstants.authPushMeta),
      token: accessToken,
      body: jsonEncode(payload),
    );

    _log('UPDATE PUSH META', res);
    _checkStatus(res);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USERS
  // ══════════════════════════════════════════════════════════════════════════

  /// GET /users/:id
  static Future<UserModel> getUser({
    required String token,
    required String userId,
  }) async {
    final url = ApiConstants.userById(userId);
    _logRequest('GET USER', url);

    final res = await _authorizedGet(uri: Uri.parse(url), token: token);

    _log('GET USER', res);
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return UserModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// GET /users?page=1&limit=20
  static Future<Map<String, dynamic>> listUsers({
    required String token,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse(ApiConstants.users).replace(
      queryParameters: {'page': page.toString(), 'limit': limit.toString()},
    );
    _logRequest('LIST USERS', uri.toString());

    final res = await _authorizedGet(uri: uri, token: token);

    _log('LIST USERS', res);
    _checkStatus(res);
    return _decodedBody(res);
  }

  /// POST /users
  static Future<UserModel> createUser({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    _logRequest('CREATE USER', ApiConstants.users, body: payload);

    final res = await _authorizedPost(
      uri: Uri.parse(ApiConstants.users),
      token: token,
      body: jsonEncode(payload),
    );

    _log('CREATE USER', res);
    _checkStatus(res);
    return UserModel.fromJson(_decodedDataMap(res));
  }

  /// POST /users/import
  static Future<Map<String, dynamic>> importUsers({
    required String token,
    required List<Map<String, dynamic>> users,
  }) async {
    final payload = {'users': users};
    _logRequest('IMPORT USERS', ApiConstants.usersImport, body: payload);

    final res = await _authorizedPost(
      uri: Uri.parse(ApiConstants.usersImport),
      token: token,
      body: jsonEncode(payload),
    );

    _log('IMPORT USERS', res);
    _checkStatus(res);
    return _decodedBody(res);
  }

  /// PATCH /users/:id
  static Future<UserModel> updateUser({
    required String token,
    required String userId,
    required Map<String, dynamic> fields,
  }) async {
    final url = ApiConstants.userById(userId);
    _logRequest('UPDATE USER', url, body: fields);

    final res = await _authorizedPatch(
      uri: Uri.parse(url),
      token: token,
      body: jsonEncode(fields),
    );

    _log('UPDATE USER', res);
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return UserModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// PATCH /users/:id  { password }
  /// Helper wrapper for password update flow.
  static Future<UserModel> updateUserPassword({
    required String token,
    required String userId,
    required String newPassword,
  }) async {
    return updateUser(
      token: token,
      userId: userId,
      fields: {'password': newPassword},
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAKHMIN
  // ══════════════════════════════════════════════════════════════════════════

  /// Parses takhmin history whether the API returns `{ "data": [...] }` or a raw JSON array.
  static List<Map<String, dynamic>> _takhminHistoryListFromResponse(
    http.Response res,
  ) {
    if (res.body.trim().isEmpty) return [];
    final decoded = jsonDecode(res.body);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map) {
        final mapData = Map<String, dynamic>.from(data);
        final nestedRows = mapData['rows'];
        if (nestedRows is List) {
          return nestedRows
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        return [mapData];
      }

      final nestedRows = decoded['rows'];
      if (nestedRows is List) {
        return nestedRows
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      // Some environments return a single history object at the top level.
      if (decoded.containsKey('misriYear') ||
          decoded.containsKey('misri_year') ||
          decoded.containsKey('year') ||
          decoded.containsKey('takhminAmountKd') ||
          decoded.containsKey('takhmin_amount_kd') ||
          decoded.containsKey('amountKd') ||
          decoded.containsKey('amount_kd')) {
        return [decoded];
      }
    }
    return [];
  }

  /// GET /takhmin/me/history
  static Future<List<Map<String, dynamic>>> getMyTakhminHistory({
    required String token,
  }) async {
    const url = '${ApiConstants.baseUrl}/takhmin/me/history';
    _logRequest('GET MY TAKHMIN HISTORY', url);

    final res = await _authorizedGet(uri: Uri.parse(url), token: token);

    _log('GET MY TAKHMIN HISTORY', res);
    _checkStatus(res);
    return _takhminHistoryListFromResponse(res);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MUMIN DUE (external GetMuminDue, proxied by backend)
  // ══════════════════════════════════════════════════════════════════════════

  /// GET /mumin-due/me
  ///
  /// Returns the latest Takhmin & Due (by Misri-year Laagat) for the logged-in
  /// account's sabil. Returns `null` when no Sabil number is set (404) so callers
  /// can fall back to the internal takhmin source.
  static Future<MuminDueModel?> getMuminDueMe({required String token}) async {
    final url = ApiConstants.muminDueMe;
    _logRequest('GET MUMIN DUE ME', url);

    final res = await _authorizedGet(uri: Uri.parse(url), token: token);

    _log('GET MUMIN DUE ME', res);
    if (res.statusCode == 404) return null;
    _checkStatus(res);
    return MuminDueModel.fromJson(_decodedDataMap(res));
  }

  /// GET /thali/me/pauses
  static Future<List<ThaliPauseModel>> getMyThaliPauses({
    required String token,
  }) async {
    final url = ApiConstants.thaliMePauses;
    final uri = Uri.parse(url);
    _logRequest('GET MY THALI PAUSES', url);
    final res = await _authorizedGet(
      uri: uri,
      token: token,
      extraHeaders: _ngrokExtraIfNeeded(uri),
    );
    _log('GET MY THALI PAUSES', res);
    _checkStatus(res);
    return _decodedDataList(res).map(ThaliPauseModel.fromJson).toList();
  }

  /// POST /thali/me/pauses
  static Future<ThaliPauseModel> createMyThaliPause({
    required String token,
    required String startDateYmd,
    required String endDateYmd,
    String? reason,
  }) async {
    final url = ApiConstants.thaliMePauses;
    final payload = <String, dynamic>{
      'startDate': startDateYmd,
      'endDate': endDateYmd,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };
    _logRequest('POST MY THALI PAUSE', url, body: payload);
    final uri = Uri.parse(url);
    final res = await _authorizedPost(
      uri: uri,
      token: token,
      body: jsonEncode(payload),
      extraHeaders: _ngrokExtraIfNeeded(uri),
    );
    _log('POST MY THALI PAUSE', res);
    _checkStatus(res);
    final data = _decodedDataMap(res);
    return ThaliPauseModel.fromJson(data);
  }

  /// PATCH /thali/me/pauses/:id  (e.g. cancel: isActive: false)
  static Future<ThaliPauseModel> patchMyThaliPause({
    required String token,
    required String pauseId,
    bool? isActive,
  }) async {
    final url = ApiConstants.thaliMePauseById(pauseId);
    final payload = <String, dynamic>{
      if (isActive != null) 'isActive': isActive,
    };
    _logRequest('PATCH MY THALI PAUSE', url, body: payload);
    final uri = Uri.parse(url);
    final res = await _authorizedPatch(
      uri: uri,
      token: token,
      body: jsonEncode(payload),
      extraHeaders: _ngrokExtraIfNeeded(uri),
    );
    _log('PATCH MY THALI PAUSE', res);
    _checkStatus(res);
    final data = _decodedDataMap(res);
    return ThaliPauseModel.fromJson(data);
  }

  /// GET /takhmin/me?misriYear=1447
  static Future<Map<String, dynamic>> getMyTakhmin({
    required String token,
    required int misriYear,
  }) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/takhmin/me',
    ).replace(queryParameters: {'misriYear': misriYear.toString()});
    _logRequest('GET MY TAKHMIN', uri.toString());

    final res = await _authorizedGet(uri: uri, token: token);

    _log('GET MY TAKHMIN', res);
    _checkStatus(res);
    return _decodedDataMap(res);
  }

  /// GET /takhmin/app-users?misriYear=1447&page=1&limit=50
  static Future<Map<String, dynamic>> listTakhminAppUsers({
    required String token,
    required int misriYear,
    int page = 1,
    int limit = 50,
  }) async {
    final uri = Uri.parse(ApiConstants.takhminAppUsers).replace(
      queryParameters: {
        'misriYear': misriYear.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    _logRequest('LIST TAKHMIN APP USERS', uri.toString());

    final res = await _authorizedGet(uri: uri, token: token);

    _log('LIST TAKHMIN APP USERS', res);
    _checkStatus(res);
    return _decodedBody(res);
  }

  /// GET /takhmin/app-users/:userId/history
  static Future<List<Map<String, dynamic>>> getTakhminUserHistory({
    required String token,
    required String userId,
  }) async {
    final url = ApiConstants.takhminHistory(userId);
    _logRequest('GET TAKHMIN USER HISTORY', url);

    final res = await _authorizedGet(uri: Uri.parse(url), token: token);

    _log('GET TAKHMIN USER HISTORY', res);
    _checkStatus(res);
    return _decodedDataList(res);
  }

  /// PATCH /takhmin/app-users/:id
  static Future<Map<String, dynamic>> updateTakhmin({
    required String token,
    required String takhminId,
    required double takhminAmountKd,
    required int misriYear,
  }) async {
    final url = ApiConstants.takhminAmount(takhminId);
    final payload = {
      'takhminAmountKd': takhminAmountKd,
      'misriYear': misriYear,
    };
    _logRequest('UPDATE TAKHMIN', url, body: payload);

    final res = await _authorizedPatch(
      uri: Uri.parse(url),
      token: token,
      body: jsonEncode(payload),
    );

    _log('UPDATE TAKHMIN', res);
    _checkStatus(res);
    return _decodedDataMap(res);
  }

  /// PATCH /takhmin/app-users/:id/completion
  static Future<Map<String, dynamic>> updateTakhminCompletion({
    required String token,
    required String takhminId,
    required int misriYear,
    required bool completed,
  }) async {
    final url = ApiConstants.takhminCompletion(takhminId);
    final payload = {'misriYear': misriYear, 'completed': completed};
    _logRequest('UPDATE TAKHMIN COMPLETION', url, body: payload);

    final res = await _authorizedPatch(
      uri: Uri.parse(url),
      token: token,
      body: jsonEncode(payload),
    );

    _log('UPDATE TAKHMIN COMPLETION', res);
    _checkStatus(res);
    return _decodedDataMap(res);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// GET /notifications?limit=20&offset=0
  static Future<List<Map<String, dynamic>>> getNotifications({
    required String token,
    int limit = 20,
    int offset = 0,
  }) async {
    final uri = Uri.parse(ApiConstants.notifications).replace(
      queryParameters: {'limit': limit.toString(), 'offset': offset.toString()},
    );
    _logRequest('GET NOTIFICATIONS', uri.toString());

    final res = await _authorizedGet(uri: uri, token: token);

    _log('GET NOTIFICATIONS', res);
    _checkStatus(res);
    return _decodedDataList(res);
  }

  /// GET /notifications/files/:storedName
  static String notificationFileUrl(String storedName) {
    return ApiConstants.notificationFile(storedName);
  }

  /// POST /notifications (multipart/form-data)
  static Future<Map<String, dynamic>> createNotification({
    required String token,
    required String title,
    required String body,
    required String audienceMode,
    String? selectedItsNumbers,
    List<File> attachments = const [],
  }) async {
    final uri = Uri.parse(ApiConstants.notifications);
    final fields = <String, String>{
      'title': title,
      'body': body,
      'audienceMode': audienceMode,
      if (selectedItsNumbers != null && selectedItsNumbers.trim().isNotEmpty)
        'selectedItsNumbers': selectedItsNumbers,
    };
    _logRequest('CREATE NOTIFICATION', uri.toString(), body: fields);

    final res = await _authorizedMultipartPost(
      uri: uri,
      token: token,
      fields: fields,
      attachments: attachments,
    );

    _log('CREATE NOTIFICATION', res);
    _checkStatus(res);
    return _decodedBody(res);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUPPORT / CONTACT
  // ══════════════════════════════════════════════════════════════════════════

  /// GET /support
  static Future<Map<String, dynamic>> getContactInfo({required String token}) async {
    final url = ApiConstants.contact;
    _logRequest('GET CONTACT INFO', url);

    final res = await _authorizedGet(uri: Uri.parse(url), token: token);

    _log('GET CONTACT INFO', res);
    _checkStatus(res);
    // Support both `{ data: {...} }` and raw map responses.
    final body = _decodedBody(res);
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return body;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FEEDBACK (planned/optional backend routes)
  // ══════════════════════════════════════════════════════════════════════════

  /// POST /feedback
  static Future<Map<String, dynamic>> submitFeedback({
    required String token,
    String? menuId,
    String? menuDate,
    required int rating,
    String? comment,
  }) async {
    final cleanMenuId = menuId?.trim() ?? '';
    final cleanMenuDate = menuDate?.trim() ?? '';
    if (cleanMenuId.isEmpty && cleanMenuDate.isEmpty) {
      throw const ApiException(
        statusCode: 400,
        code: 'invalid_feedback_payload',
        message: 'Either menuId or menuDate is required for feedback.',
      );
    }

    final payload = {
      if (cleanMenuId.isNotEmpty) 'menuId': cleanMenuId,
      if (cleanMenuDate.isNotEmpty) 'menuDate': cleanMenuDate,
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment,
    };
    _logRequest('SUBMIT FEEDBACK', ApiConstants.feedback, body: payload);

    final res = await _authorizedPost(
      uri: Uri.parse(ApiConstants.feedback),
      token: token,
      body: jsonEncode(payload),
    );

    _log('SUBMIT FEEDBACK', res);
    _checkStatus(res);
    return _decodedBody(res);
  }

  /// GET /feedback
  static Future<Map<String, dynamic>> getFeedback({
    required String token,
    int page = 1,
    int limit = 20,
    String? menuId,
  }) async {
    final uri = Uri.parse(ApiConstants.feedback).replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        if (menuId != null && menuId.trim().isNotEmpty) 'menuId': menuId,
      },
    );
    _logRequest('GET FEEDBACK', uri.toString());

    final res = await _authorizedGet(uri: uri, token: token);

    _log('GET FEEDBACK', res);
    _checkStatus(res);
    return _decodedBody(res);
  }

  /// GET /feedback/summary
  static Future<Map<String, dynamic>> getFeedbackSummary({
    required String token,
  }) async {
    _logRequest('GET FEEDBACK SUMMARY', ApiConstants.feedbackSummary);

    final res = await _authorizedGet(
      uri: Uri.parse(ApiConstants.feedbackSummary),
      token: token,
    );

    _log('GET FEEDBACK SUMMARY', res);
    _checkStatus(res);
    return _decodedBody(res);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PACKAGES
  // ══════════════════════════════════════════════════════════════════════════

  /// GET /packages?activeOnly=true
  static Future<List<PackageModel>> getPackages({
    required String token,
    bool activeOnly = true,
  }) async {
    final uri = Uri.parse(
      ApiConstants.packages,
    ).replace(queryParameters: {'activeOnly': activeOnly.toString()});
    _logRequest('GET PACKAGES', uri.toString());

    final res = await _authorizedGet(uri: uri, token: token);

    _log('GET PACKAGES', res);
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['data'] as List<dynamic>;
    return list
        .map((e) => PackageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /packages/:id
  static Future<PackageModel> getPackageById({
    required String token,
    required String packageId,
  }) async {
    final url = ApiConstants.packageById(packageId);
    _logRequest('GET PACKAGE BY ID', url);

    final res = await _authorizedGet(uri: Uri.parse(url), token: token);

    _log('GET PACKAGE BY ID', res);
    _checkStatus(res);
    return PackageModel.fromJson(_decodedDataMap(res));
  }

  /// POST /packages
  static Future<PackageModel> createPackage({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    _logRequest('CREATE PACKAGE', ApiConstants.packages, body: payload);

    final res = await _authorizedPost(
      uri: Uri.parse(ApiConstants.packages),
      token: token,
      body: jsonEncode(payload),
    );

    _log('CREATE PACKAGE', res);
    _checkStatus(res);
    return PackageModel.fromJson(_decodedDataMap(res));
  }

  /// PATCH /packages/:id
  static Future<PackageModel> updatePackage({
    required String token,
    required String packageId,
    required Map<String, dynamic> fields,
  }) async {
    final url = ApiConstants.packageById(packageId);
    _logRequest('UPDATE PACKAGE', url, body: fields);

    final res = await _authorizedPatch(
      uri: Uri.parse(url),
      token: token,
      body: jsonEncode(fields),
    );

    _log('UPDATE PACKAGE', res);
    _checkStatus(res);
    return PackageModel.fromJson(_decodedDataMap(res));
  }

  /// DELETE /packages/:id
  static Future<Map<String, dynamic>> deletePackage({
    required String token,
    required String packageId,
  }) async {
    final url = ApiConstants.packageById(packageId);
    _logRequest('DELETE PACKAGE', url);

    final res = await _authorizedDelete(uri: Uri.parse(url), token: token);

    _log('DELETE PACKAGE', res);
    _checkStatus(res);
    return _decodedBody(res);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ZABIHAT
  // ══════════════════════════════════════════════════════════════════════════

  /// GET /zabihat?enabledOnly=true
  static Future<List<ZabihatModel>> getZabihat({
    required String token,
    bool enabledOnly = true,
  }) async {
    final uri = Uri.parse(
      ApiConstants.zabihat,
    ).replace(queryParameters: {'enabledOnly': enabledOnly.toString()});
    _logRequest('GET ZABIHAT', uri.toString());

    final res = await _authorizedGet(uri: uri, token: token);

    _log('GET ZABIHAT', res);
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['data'] as List<dynamic>;
    return list
        .map((e) => ZabihatModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /zabihat/:id
  static Future<ZabihatModel> getZabihatById({
    required String token,
    required String zabihatId,
  }) async {
    final url = ApiConstants.zabihatById(zabihatId);
    _logRequest('GET ZABIHAT BY ID', url);

    final res = await _authorizedGet(uri: Uri.parse(url), token: token);

    _log('GET ZABIHAT BY ID', res);
    _checkStatus(res);
    return ZabihatModel.fromJson(_decodedDataMap(res));
  }

  /// POST /zabihat
  static Future<ZabihatModel> createZabihat({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    _logRequest('CREATE ZABIHAT', ApiConstants.zabihat, body: payload);

    final res = await _authorizedPost(
      uri: Uri.parse(ApiConstants.zabihat),
      token: token,
      body: jsonEncode(payload),
    );

    _log('CREATE ZABIHAT', res);
    _checkStatus(res);
    return ZabihatModel.fromJson(_decodedDataMap(res));
  }

  /// PATCH /zabihat/:id
  static Future<ZabihatModel> updateZabihat({
    required String token,
    required String zabihatId,
    required Map<String, dynamic> fields,
  }) async {
    final url = ApiConstants.zabihatById(zabihatId);
    _logRequest('UPDATE ZABIHAT', url, body: fields);

    final res = await _authorizedPatch(
      uri: Uri.parse(url),
      token: token,
      body: jsonEncode(fields),
    );

    _log('UPDATE ZABIHAT', res);
    _checkStatus(res);
    return ZabihatModel.fromJson(_decodedDataMap(res));
  }

  /// DELETE /zabihat/:id
  static Future<Map<String, dynamic>> deleteZabihat({
    required String token,
    required String zabihatId,
  }) async {
    final url = ApiConstants.zabihatById(zabihatId);
    _logRequest('DELETE ZABIHAT', url);

    final res = await _authorizedDelete(uri: Uri.parse(url), token: token);

    _log('DELETE ZABIHAT', res);
    _checkStatus(res);
    return _decodedBody(res);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAYMENTS
  // ══════════════════════════════════════════════════════════════════════════

  /// GET /payments/receipts
  static Future<List<PaymentModel>> getPaymentReceipts({
    required String token,
    int page = 1,
    int limit = 50,
    int? misriYear,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (misriYear != null) 'misriYear': misriYear.toString(),
    };
    final uri = Uri.parse(
      ApiConstants.paymentReceipts,
    ).replace(queryParameters: params);
    // _logRequest('GET PAYMENT RECEIPTS', uri.toString());
    _logPaymentRequest('GET PAYMENT RECEIPTS', uri.toString());

    final res = await _authorizedGet(uri: uri, token: token);

    // _log('GET PAYMENT RECEIPTS', res);
    _logPaymentResponse('GET PAYMENT RECEIPTS', res);
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['data'] as List<dynamic>;
    return list
        .map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /payments/summary?misriYear=1447
  static Future<Map<String, dynamic>> getPaymentSummary({
    required String token,
    required int misriYear,
  }) async {
    final uri = Uri.parse(
      ApiConstants.paymentSummary,
    ).replace(queryParameters: {'misriYear': misriYear.toString()});
    // _logRequest('GET PAYMENT SUMMARY', uri.toString());
    _logPaymentRequest('GET PAYMENT SUMMARY', uri.toString());

    final res = await _authorizedGet(uri: uri, token: token);

    // _log('GET PAYMENT SUMMARY', res);
    _logPaymentResponse('GET PAYMENT SUMMARY', res);
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
  }

  /// GET /payments/eligible-users?misriYear=1447
  ///
  /// Returns users the backend considers eligible to pay for that Misri year (computed
  /// from users + user_takhmin; not a stored flag on User).
  static Future<List<UserModel>> getPaymentEligibleUsers({
    required String token,
    required int misriYear,
  }) async {
    final uri = Uri.parse(
      ApiConstants.paymentEligible,
    ).replace(queryParameters: {'misriYear': misriYear.toString()});
    // _logRequest('GET PAYMENT ELIGIBLE USERS', uri.toString());
    _logPaymentRequest('GET PAYMENT ELIGIBLE USERS', uri.toString());

    final res = await _authorizedGet(uri: uri, token: token);

    // _log('GET PAYMENT ELIGIBLE USERS', res);
    _logPaymentResponse('GET PAYMENT ELIGIBLE USERS', res);
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['data'] as List<dynamic>? ?? const [];
    return list
        .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /settings/min-installment
  ///
  /// Returns the minimum installment/payment amount in KD (admin-configurable).
  static Future<double> getMinInstallmentKd({
    required String token,
  }) async {
    final uri = Uri.parse(ApiConstants.settingsMinInstallment);
    _logRequest('GET MIN INSTALLMENT', uri.toString());

    final res = await _authorizedGet(uri: uri, token: token);

    _log('GET MIN INSTALLMENT', res);
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      final v = data['minInstallmentKd'];
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return 50.0;
  }

  /// POST /payments/receipts
  static Future<Map<String, dynamic>> createPaymentReceipt({
    required String token,
    required String userId,
    required int misriYear,
    required double amountKd,
    String? notes,
  }) async {
    final payload = {
      'userId': userId,
      'misriYear': misriYear,
      'amountKd': amountKd,
      if (notes != null) 'notes': notes,
    };
    // _logRequest(
    //   'CREATE PAYMENT RECEIPT',
    //   ApiConstants.paymentReceipts,
    //   body: payload,
    // );
    _logPaymentRequest(
      'CREATE PAYMENT RECEIPT',
      ApiConstants.paymentReceipts,
      body: payload,
    );

    final res = await _authorizedPost(
      uri: Uri.parse(ApiConstants.paymentReceipts),
      token: token,
      body: jsonEncode(payload),
    );

    // _log('CREATE PAYMENT RECEIPT', res);
    _logPaymentResponse('CREATE PAYMENT RECEIPT', res);
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  /// POST /payments/upayments/initiate
  static Future<Map<String, dynamic>> initiateUPayment({
    required String token,
    required double amountKd,
    required String productName,

    /// Correlation id for backend `initiate_context_key` / pending reuse (not UPayments merchant `order.id`).
    String? clientOrderId,
    bool forceNew = false,
  }) async {
    final payload = {
      'amountKd': amountKd,
      'productName': productName,
      if (clientOrderId != null && clientOrderId.trim().length >= 6)
        'orderId': clientOrderId.trim(),
      if (forceNew) 'forceNew': true,
    };
    // _logRequest(
    //   'INITIATE UPAYMENTS',
    //   ApiConstants.paymentUPaymentsInitiate,
    //   body: payload,
    // );
    _logPaymentRequest(
      'INITIATE UPAYMENTS',
      ApiConstants.paymentUPaymentsInitiate,
      body: payload,
    );

    final res = await _authorizedPost(
      uri: Uri.parse(ApiConstants.paymentUPaymentsInitiate),
      token: token,
      body: jsonEncode(payload),
    );

    // _log('INITIATE UPAYMENTS', res);
    _logPaymentResponse('INITIATE UPAYMENTS', res);
    _checkStatus(res);
    final body = _decodedBody(res);
    final dataRaw = body['data'];
    if (dataRaw is Map<String, dynamic>) {
      final gatewayError = (dataRaw['error'] ?? '').toString().trim();
      if (gatewayError.isNotEmpty) {
        throw ApiException(
          statusCode: res.statusCode,
          code: 'UPAYMENT_GATEWAY_ERROR',
          message: (body['message'] as String?)?.trim().isNotEmpty == true
              ? (body['message'] as String).trim()
              : 'Payment gateway returned an error.',
          details: gatewayError,
        );
      }
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    // Some backends return { success, paymentURL, orderId } without a data wrapper.
    return body;
  }

  /// GET /payments/upayments/verify/:orderId
  static Future<Map<String, dynamic>> verifyUPayment({
    required String token,
    required String orderId,
  }) async {
    final url = ApiConstants.paymentUPaymentsVerify(orderId);
    // _logRequest('VERIFY UPAYMENTS', url);
    _logPaymentRequest('VERIFY UPAYMENTS', url);

    final res = await _authorizedGet(uri: Uri.parse(url), token: token);

    // _log('VERIFY UPAYMENTS', res);
    _logPaymentResponse('VERIFY UPAYMENTS', res);
    _checkStatus(res);
    return _decodedDataMap(res);
  }

  /// GET /payments/upayments/orders/:orderId
  static Future<Map<String, dynamic>> getUPaymentOrder({
    required String token,
    required String orderId,
  }) async {
    final url = ApiConstants.paymentUPaymentsOrder(orderId);
    // _logRequest('GET UPAYMENTS ORDER', url);
    _logPaymentRequest('GET UPAYMENTS ORDER', url);

    final res = await _authorizedGet(uri: Uri.parse(url), token: token);

    // _log('GET UPAYMENTS ORDER', res);
    _logPaymentResponse('GET UPAYMENTS ORDER', res);
    _checkStatus(res);
    return _decodedDataMap(res);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MENUS
  // ══════════════════════════════════════════════════════════════════════════

  /// GET /menu-exclusions/me?menuDate=YYYY-MM-DD
  static Future<List<String>> getMyMenuExclusions({
    required String token,
    required String menuDateYmd,
  }) async {
    final uri = Uri.parse(ApiConstants.menuExclusionsMe).replace(
      queryParameters: {'menuDate': menuDateYmd},
    );
    _logRequest('GET MY MENU EXCLUSIONS', uri.toString());
    final res = await _authorizedGet(uri: uri, token: token);
    _log('GET MY MENU EXCLUSIONS', res);
    _checkStatus(res);
    final data = _decodedDataMap(res);
    final items = data['items'];
    if (items is! List) return const [];
    return items.map((e) => e.toString()).toList();
  }

  /// PUT /menu-exclusions/me — replaces exclusions for that calendar day (max 2 items; API enforces).
  static Future<List<String>> putMyMenuExclusions({
    required String token,
    required String menuDateYmd,
    required List<String> items,
  }) async {
    final payload = {'menuDate': menuDateYmd, 'items': items};
    _logRequest('PUT MY MENU EXCLUSIONS', ApiConstants.menuExclusionsMe, body: payload);
    final res = await _authorizedPut(
      uri: Uri.parse(ApiConstants.menuExclusionsMe),
      token: token,
      body: jsonEncode(payload),
    );
    _log('PUT MY MENU EXCLUSIONS', res);
    _checkStatus(res);
    final data = _decodedDataMap(res);
    final out = data['items'];
    if (out is! List) return items;
    return out.map((e) => e.toString()).toList();
  }

  /// GET /menus?from=YYYY-MM-DD&to=YYYY-MM-DD
  static Future<List<MenuModel>> getMenus({
    required String token,
    String? from,
    String? to,
  }) async {
    final params = <String, String>{
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    };
    final uri = Uri.parse(
      ApiConstants.menus,
    ).replace(queryParameters: params.isEmpty ? null : params);
    _logRequest('GET MENUS', uri.toString());

    final res = await _authorizedGet(uri: uri, token: token);

    _log('GET MENUS', res);
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['data'] as List<dynamic>;
    return list
        .map((e) => MenuModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /menus/:id
  static Future<MenuModel> getMenuById({
    required String token,
    required String menuId,
  }) async {
    final url = ApiConstants.menuById(menuId);
    _logRequest('GET MENU BY ID', url);

    final res = await _authorizedGet(uri: Uri.parse(url), token: token);

    _log('GET MENU BY ID', res);
    _checkStatus(res);
    return MenuModel.fromJson(_decodedDataMap(res));
  }

  /// POST /menus
  static Future<MenuModel> createMenu({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    _logRequest('CREATE MENU', ApiConstants.menus, body: payload);

    final res = await _authorizedPost(
      uri: Uri.parse(ApiConstants.menus),
      token: token,
      body: jsonEncode(payload),
    );

    _log('CREATE MENU', res);
    _checkStatus(res);
    return MenuModel.fromJson(_decodedDataMap(res));
  }

  /// PATCH /menus/:id
  static Future<MenuModel> updateMenu({
    required String token,
    required String menuId,
    required Map<String, dynamic> fields,
  }) async {
    final url = ApiConstants.menuById(menuId);
    _logRequest('UPDATE MENU', url, body: fields);

    final res = await _authorizedPatch(
      uri: Uri.parse(url),
      token: token,
      body: jsonEncode(fields),
    );

    _log('UPDATE MENU', res);
    _checkStatus(res);
    return MenuModel.fromJson(_decodedDataMap(res));
  }

  /// DELETE /menus/:id
  static Future<Map<String, dynamic>> deleteMenu({
    required String token,
    required String menuId,
  }) async {
    final url = ApiConstants.menuById(menuId);
    _logRequest('DELETE MENU', url);

    final res = await _authorizedDelete(uri: Uri.parse(url), token: token);

    _log('DELETE MENU', res);
    _checkStatus(res);
    return _decodedBody(res);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ERROR HANDLING
  // ══════════════════════════════════════════════════════════════════════════

  static void _checkStatus(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message = 'Something went wrong. Please try again.';
    String code = 'UNKNOWN_ERROR';

    var parsedBody = false;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      parsedBody = true;
      final error = body['error'] as Map<String, dynamic>?;
      if (error != null) {
        code = error['code'] as String? ?? code;
        message = error['message'] as String? ?? message;
      }
    } catch (_) {}

    final sc = response.statusCode;
    final stillGeneric =
        message == 'Something went wrong. Please try again.';
    if (stillGeneric &&
        (sc == 502 || sc == 503 || sc == 504 || (sc == 500 && !parsedBody))) {
      message =
          'Service is temporarily unavailable (often the database or hosting is unreachable). Please try again later.';
    }

    switch (code) {
      case 'DATABASE_UNAVAILABLE':
        message =
            'Cannot reach the database right now. Please try again in a few minutes or contact support if this continues.';
        break;
      case 'DATABASE_NOT_READY':
        message =
            'This feature is not ready on the server yet (database migration may be pending).';
        break;
      case 'DATABASE_POOL_TIMEOUT':
        message =
            'The database is temporarily overloaded. Wait a few seconds and try again.';
        break;
      case 'MENU_NOT_FOUND':
        message =
            'No published menu for that day on this API. Menus and exclusions must use the same server (check ApiConstants).';
        break;
      case 'ITS_NOT_FOUND':
        message = 'No account found with this ITS Number.';
        break;
      case 'INVALID_PASSWORD':
        message = 'Incorrect password. Please try again.';
        break;
      case 'ACCOUNT_INACTIVE':
        message = 'Your account is inactive. Contact support.';
        break;
      case 'CHANNEL_NOT_ALLOWED':
        message = 'This account type cannot log in on mobile.';
        break;
      case 'PAYMENT_NOT_APPLICABLE':
        message = 'Payment is not applicable for this user.';
        break;
      case 'PAYMENT_PREREQUISITE':
        message = 'Takhmin must be completed before recording a payment.';
        break;
    }

    final url = response.request == null
        ? '(unknown URL)'
        : response.request!.url.toString();
    final raw = response.body;
    final preview = raw.isEmpty
        ? '(empty body)'
        : (raw.length > 800 ? '${raw.substring(0, 800)}…' : raw);
    dev.log(
      'HTTP $sc $code — $message\n'
      'URL: $url\n'
      'Body:\n$preview',
      name: 'FMB_API',
    );
    debugPrint('[FMB_API] HTTP $sc $code — $message');
    debugPrint('[FMB_API] URL: $url');
    debugPrint('[FMB_API] Body (truncated):\n$preview');

    throw ApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
    );
  }
}

/// Thrown by [ApiManager] when the server returns a non-2xx response.
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final String? details;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() {
    final d = details?.trim() ?? '';
    if (d.isEmpty) return 'ApiException($statusCode, $code): $message';
    return 'ApiException($statusCode, $code): $message | Details: $d';
  }
}
