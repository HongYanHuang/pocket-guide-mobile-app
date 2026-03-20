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
      print('🔵 AuthService.handleWebCallback: Starting');
      print('   code: ${code.substring(0, 20)}...');
      print('   state: $state');

      // 1. Validate state to prevent CSRF
      final savedState = await _storageService.getOAuthState();
      print('🔵 AuthService.handleWebCallback: Validating state');
      print('   saved state: $savedState');
      print('   returned state: $state');

      if (savedState != state) {
        print('❌ AuthService.handleWebCallback: State mismatch!');
        throw Exception('Invalid state parameter - possible CSRF attack');
      }

      print('✅ AuthService.handleWebCallback: State validated');

      // 2. Get code verifier
      final codeVerifier = await _storageService.getCodeVerifier();
      print('🔵 AuthService.handleWebCallback: Got code verifier: ${codeVerifier?.substring(0, 20)}...');

      if (codeVerifier == null) {
        print('❌ AuthService.handleWebCallback: No code verifier found');
        throw Exception('Missing PKCE code verifier');
      }

      // 3. Exchange code for tokens
      print('🔵 AuthService.handleWebCallback: Exchanging code for tokens...');
      await _handleCallback(code, state, codeVerifier);

      // 4. Clean up temporary storage
      print('🔵 AuthService.handleWebCallback: Cleaning up');
      await _storageService.deleteCodeVerifier();
      await _storageService.deleteOAuthState();

      print('✅ AuthService.handleWebCallback: Success!');
      return true;
    } catch (e, stackTrace) {
      print('❌ AuthService.handleWebCallback: Error: $e');
      print('   Stack trace: $stackTrace');

      // Clean up on error
      await _storageService.deleteCodeVerifier();
      await _storageService.deleteOAuthState();
      return false;
    }
  }

  // Initiate Google OAuth login
  Future<bool> login() async {
    try {
      print('🔵 AuthService.login: Starting OAuth login...');

      // 1. Generate PKCE parameters
      print('🔵 AuthService.login: Step 1 - Generating PKCE');
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      print('✅ Generated PKCE challenge: ${codeChallenge.substring(0, 20)}...');

      // 2. Store code verifier for callback
      print('🔵 AuthService.login: Step 2 - Storing code verifier');
      await _storageService.saveCodeVerifier(codeVerifier);
      print('✅ Saved code verifier');

      // 3. Get Google OAuth URL from backend
      print('🔵 AuthService.login: Step 3 - Getting OAuth URL from backend');
      // For web: use http://localhost:<port>/auth/callback
      // For mobile: use custom URL scheme pocketguide://auth/callback
      final redirectUri = _isWebMode
          ? '${Uri.base.origin}/auth/callback'  // Web mode
          : '$_callbackUrlScheme://auth/callback';  // Mobile mode
      print('   Redirect URI: $redirectUri');

      final response = await _apiService.initiateGoogleLogin(
        redirectUri: redirectUri,
        codeChallenge: codeChallenge,
      );

      if (response == null || response['auth_url'] == null || response['state'] == null) {
        print('❌ No auth URL or state in response');
        throw Exception('Failed to get authorization URL from backend');
      }

      final authUrl = response['auth_url'] as String;
      final state = response['state'] as String;
      print('✅ Got auth URL from backend: ${authUrl.substring(0, 60)}...');
      print('✅ Got state from backend: $state');

      // 4. Store state from backend for callback validation
      print('🔵 AuthService.login: Step 4 - Storing state from backend');
      await _storageService.saveOAuthState(state);
      print('✅ Saved state from backend');

      // 5. Redirect to Google OAuth
      print('🔵 AuthService.login: Step 5 - Redirecting to Google');
      print('   NOTE: After Google login, you\'ll be redirected to /auth/callback');
      print('   Watch the console logs on that page!');

      if (_isWebMode) {
        // For web: use window.location to redirect
        // The page will reload at /auth/callback after Google OAuth
        html.window.location.href = authUrl;

        // Return true immediately - the callback will be handled by AuthCallbackScreen
        return true;
      } else {
        // For mobile: use FlutterWebAuth2
        print('🔵 AuthService.login: Using FlutterWebAuth2 for mobile');
        final result = await FlutterWebAuth2.authenticate(
          url: authUrl,
          callbackUrlScheme: _callbackUrlScheme,
        );

        print('✅ OAuth callback received: $result');

        // 5. Extract code and state from callback URL
        final uri = Uri.parse(result);
        final code = uri.queryParameters['code'];
        final returnedState = uri.queryParameters['state'];

        if (code == null || returnedState == null) {
          print('❌ Missing code or state in callback');
          throw Exception('Missing authorization code or state in callback');
        }

        // 6. Validate state to prevent CSRF
        final savedState = await _storageService.getOAuthState();
        if (savedState != returnedState) {
          print('❌ State mismatch!');
          throw Exception('Invalid state parameter - possible CSRF attack');
        }

        print('✅ State validated successfully');

        // 7. Exchange code for tokens
        final savedVerifier = await _storageService.getCodeVerifier();
        if (savedVerifier == null) {
          print('❌ No code verifier found');
          throw Exception('Missing PKCE code verifier');
        }

        await _handleCallback(code, returnedState, savedVerifier);

        // 8. Clean up temporary storage
        await _storageService.deleteCodeVerifier();
        await _storageService.deleteOAuthState();

        print('✅ Login completed successfully');
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
