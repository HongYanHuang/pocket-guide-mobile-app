import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:pocket_guide_mobile/services/storage_service.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/models/user_model.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';

class AuthService {
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();

  // For web mode: use http://localhost redirect
  // For mobile: use custom URL scheme (pocketguide://)
  static const bool _isWebMode = true; // Set to false for mobile testing
  static const String _callbackUrlScheme = 'pocketguide';

  // PKCE: Generate random code verifier
  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  // PKCE: Generate code challenge from verifier
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  // Generate random state for CSRF protection
  String _generateState() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  // Initiate Google OAuth login
  Future<bool> login() async {
    try {
      print('Starting OAuth login...');

      // 1. Generate PKCE parameters
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      final state = _generateState();

      print('Generated PKCE challenge');

      // 2. Store code verifier and state for callback
      await _storageService.saveCodeVerifier(codeVerifier);
      await _storageService.saveOAuthState(state);

      print('Saved code verifier and state');

      // 3. Get Google OAuth URL from backend
      // For web: use http://localhost:<port>/auth/callback
      // For mobile: use custom URL scheme pocketguide://auth/callback
      final redirectUri = _isWebMode
          ? '${Uri.base.origin}/auth/callback'  // Web mode
          : '$_callbackUrlScheme://auth/callback';  // Mobile mode
      print('Calling backend with redirectUri: $redirectUri');

      final response = await _apiService.initiateGoogleLogin(
        redirectUri: redirectUri,
        codeChallenge: codeChallenge,
      );

      if (response == null || response['auth_url'] == null) {
        throw Exception('Failed to get authorization URL from backend');
      }

      final authUrl = response['auth_url'] as String;
      print('Got auth URL from backend: ${authUrl.substring(0, 50)}...');

      // 4. Open browser for OAuth
      print('Opening browser for OAuth...');

      final String result;
      if (_isWebMode) {
        // For web: redirect to Google OAuth, then handle callback on return
        result = await FlutterWebAuth2.authenticate(
          url: authUrl,
          callbackUrlScheme: 'http',  // Web uses http/https callback
        );
      } else {
        // For mobile: use custom URL scheme
        result = await FlutterWebAuth2.authenticate(
          url: authUrl,
          callbackUrlScheme: _callbackUrlScheme,
        );
      }

      print('OAuth callback received: $result');

      // 5. Extract code and state from callback URL
      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];
      final returnedState = uri.queryParameters['state'];

      if (code == null || returnedState == null) {
        throw Exception('Missing authorization code or state in callback');
      }

      // 6. Validate state to prevent CSRF
      final savedState = await _storageService.getOAuthState();
      if (savedState != returnedState) {
        throw Exception('Invalid state parameter - possible CSRF attack');
      }

      print('State validated successfully');

      // 7. Exchange code for tokens
      final savedVerifier = await _storageService.getCodeVerifier();
      if (savedVerifier == null) {
        throw Exception('Missing PKCE code verifier');
      }

      await _handleCallback(code, returnedState, savedVerifier);

      // 8. Clean up temporary storage
      await _storageService.deleteCodeVerifier();
      await _storageService.deleteOAuthState();

      print('Login completed successfully');
      return true;
    } catch (e) {
      print('Login error: $e');
      // Clean up on error
      await _storageService.deleteCodeVerifier();
      await _storageService.deleteOAuthState();
      return false;
    }
  }

  // Handle OAuth callback and exchange code for tokens
  Future<void> _handleCallback(String code, String state, String codeVerifier) async {
    try {
      print('Exchanging authorization code for tokens...');

      final tokenResponse = await _apiService.exchangeCodeForTokens(
        code: code,
        state: state,
        codeVerifier: codeVerifier,
      );

      if (tokenResponse == null) {
        throw Exception('Failed to exchange code for tokens');
      }

      // Save tokens securely
      await _storageService.saveAccessToken(tokenResponse.accessToken);
      await _storageService.saveRefreshToken(tokenResponse.refreshToken);

      print('Tokens saved successfully');
    } catch (e) {
      print('Error handling callback: $e');
      rethrow;
    }
  }

  // Refresh access token
  Future<bool> refreshAccessToken() async {
    try {
      print('Refreshing access token...');

      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken == null) {
        print('No refresh token available');
        return false;
      }

      final tokenResponse = await _apiService.refreshToken(refreshToken);
      if (tokenResponse == null) {
        print('Failed to refresh token');
        return false;
      }

      // Save new access token
      await _storageService.saveAccessToken(tokenResponse.accessToken);
      // Note: refresh token stays the same

      print('Access token refreshed successfully');
      return true;
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final hasTokens = await _storageService.hasTokens();
    if (!hasTokens) {
      return false;
    }

    // Try to get user info to validate token
    try {
      final user = await getCurrentUser();
      return user != null;
    } catch (e) {
      // If getting user fails, try to refresh token
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        try {
          final user = await getCurrentUser();
          return user != null;
        } catch (e) {
          return false;
        }
      }
      return false;
    }
  }

  // Get current user info
  Future<User?> getCurrentUser() async {
    try {
      final accessToken = await _storageService.getAccessToken();
      if (accessToken == null) {
        return null;
      }

      final userInfo = await _apiService.getCurrentUser(accessToken);
      if (userInfo == null) {
        return null;
      }

      return User(
        email: userInfo.email,
        name: userInfo.name,
        picture: userInfo.picture,
        role: userInfo.role ?? 'client_user',
      );
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      print('Logging out...');

      final accessToken = await _storageService.getAccessToken();
      final refreshToken = await _storageService.getRefreshToken();

      if (accessToken != null && refreshToken != null) {
        // Call backend logout endpoint
        await _apiService.logout(accessToken, refreshToken);
      }
    } catch (e) {
      print('Error during logout: $e');
    } finally {
      // Always clear local tokens
      await _storageService.clearTokens();
      print('Logged out successfully');
    }
  }
}
