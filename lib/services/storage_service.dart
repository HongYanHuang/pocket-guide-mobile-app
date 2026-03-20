import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _codeVerifierKey = 'pkce_code_verifier';
  static const String _oauthStateKey = 'oauth_state';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Access Token
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  // Refresh Token
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  // PKCE Code Verifier
  Future<void> saveCodeVerifier(String verifier) async {
    await _storage.write(key: _codeVerifierKey, value: verifier);
  }

  Future<String?> getCodeVerifier() async {
    return await _storage.read(key: _codeVerifierKey);
  }

  Future<void> deleteCodeVerifier() async {
    await _storage.delete(key: _codeVerifierKey);
  }

  // OAuth State
  Future<void> saveOAuthState(String state) async {
    await _storage.write(key: _oauthStateKey, value: state);
  }

  Future<String?> getOAuthState() async {
    return await _storage.read(key: _oauthStateKey);
  }

  Future<void> deleteOAuthState() async {
    await _storage.delete(key: _oauthStateKey);
  }

  // Clear all tokens
  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _codeVerifierKey);
    await _storage.delete(key: _oauthStateKey);
  }

  // Check if user has tokens
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    return accessToken != null && refreshToken != null;
  }
}
