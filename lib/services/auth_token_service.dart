import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenService {
  AuthTokenService._();
  static final AuthTokenService instance = AuthTokenService._();

  static const _accessTokenKey = 'fmb_access_token';
  static const _refreshTokenKey = 'fmb_refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _cachedAccessToken;
  String? _cachedRefreshToken;

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    await _storage.write(key: _accessTokenKey, value: accessToken);

    if (refreshToken != null && refreshToken.isNotEmpty) {
      _cachedRefreshToken = refreshToken;
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
    /* debugPrint(
      '[AuthTokenService] Tokens saved. refreshTokenPresent: ${refreshToken != null && refreshToken.isNotEmpty}',
    );*/
  }

  Future<String> getAccessToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken!;
    _cachedAccessToken = await _storage.read(key: _accessTokenKey) ?? '';
    return _cachedAccessToken ?? '';
  }

  Future<String> getRefreshToken() async {
    if (_cachedRefreshToken != null) return _cachedRefreshToken!;
    _cachedRefreshToken = await _storage.read(key: _refreshTokenKey) ?? '';
    return _cachedRefreshToken ?? '';
  }

  Future<void> setAccessToken(String accessToken) async {
    _cachedAccessToken = accessToken;
    await _storage.write(key: _accessTokenKey, value: accessToken);
  }

  Future<void> clearTokens() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    // debugPrint('[AuthTokenService] Tokens cleared.');
  }
}
