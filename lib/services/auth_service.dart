import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:pocket_guide_mobile/services/storage_service.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/models/user_model.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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

  // Handle OAuth callback from web (called by AuthCallbackScreen)
  Future<bool> handleWebCallback(String code, String state) async {
    try {
      print('🔐 handleWebCallback: Starting callback processing');
      print('   Code: ${code.substring(0, 10)}...');
      print('   State: ${state.substring(0, 10)}...');

      // Validate state to prevent CSRF
      final savedState = await _storageService.getOAuthState();
      print('   Saved state: ${savedState?.substring(0, 10)}...');

      if (savedState != state) {
        print('❌ State mismatch! Saved: $savedState, Received: $state');
        throw Exception('Invalid state parameter - possible CSRF attack');
      }
      print('✅ State validation passed');

      // Get code verifier
      final codeVerifier = await _storageService.getCodeVerifier();
      if (codeVerifier == null) {
        print('❌ No code verifier found in storage');
        throw Exception('Missing PKCE code verifier');
      }
      print('✅ Code verifier retrieved');

      // Exchange code for tokens
      print('🔐 Exchanging code for tokens...');
      await _handleCallback(code, state, codeVerifier);
      print('✅ Token exchange successful');

      // Clean up temporary storage
      await _storageService.deleteCodeVerifier();
      await _storageService.deleteOAuthState();
      print('✅ Temporary storage cleaned up');

      return true;
    } catch (e) {
      print('❌ Login error in handleWebCallback: $e');
      // Clean up on error
      await _storageService.deleteCodeVerifier();
      await _storageService.deleteOAuthState();
      return false;
    }
  }

  // Initiate Google OAuth login
  Future<bool> login() async {
    try {
      // Generate PKCE parameters
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);

      // Store code verifier for callback
      await _storageService.saveCodeVerifier(codeVerifier);

      // Get Google OAuth URL from backend
      // For web: use http://localhost:<port>/auth/callback
      // For mobile: use custom URL scheme pocketguide://auth/callback
      final redirectUri = _isWebMode
          ? '${Uri.base.origin}/auth/callback'  // Web mode
          : '$_callbackUrlScheme://auth/callback';  // Mobile mode

      final response = await _apiService.initiateGoogleLogin(
        redirectUri: redirectUri,
        codeChallenge: codeChallenge,
      );

      if (response == null || response['auth_url'] == null || response['state'] == null) {
        throw Exception('Failed to get authorization URL from backend');
      }

      final authUrl = response['auth_url'] as String;
      final state = response['state'] as String;

      // Store state from backend for callback validation
      await _storageService.saveOAuthState(state);

      if (_isWebMode) {
        // For web: use window.location to redirect
        // The page will reload at /auth/callback after Google OAuth
        print('🔐 Redirecting to Google OAuth: $authUrl');
        html.window.location.href = authUrl;

        // Return false because the page will redirect away
        // The callback will be handled by AuthCallbackScreen after Google auth
        return false;
      } else {
        // For mobile: use FlutterWebAuth2
        final result = await FlutterWebAuth2.authenticate(
          url: authUrl,
          callbackUrlScheme: _callbackUrlScheme,
        );

        // Extract code and state from callback URL
        final uri = Uri.parse(result);
        final code = uri.queryParameters['code'];
        final returnedState = uri.queryParameters['state'];

        if (code == null || returnedState == null) {
          throw Exception('Missing authorization code or state in callback');
        }

        // Validate state to prevent CSRF
        final savedState = await _storageService.getOAuthState();
        if (savedState != returnedState) {
          throw Exception('Invalid state parameter - possible CSRF attack');
        }

        // Exchange code for tokens
        final savedVerifier = await _storageService.getCodeVerifier();
        if (savedVerifier == null) {
          throw Exception('Missing PKCE code verifier');
        }

        await _handleCallback(code, returnedState, savedVerifier);

        // Clean up temporary storage
        await _storageService.deleteCodeVerifier();
        await _storageService.deleteOAuthState();

        return true;
      }
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
    } catch (e) {
      print('Error handling callback: $e');
      rethrow;
    }
  }

  // Refresh access token
  Future<bool> refreshAccessToken() async {
    try {

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

  // Get access token
  Future<String?> getAccessToken() async {
    return await _storageService.getAccessToken();
  }

  // Logout
  Future<void> logout() async {
    try {
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
    }
  }
}
