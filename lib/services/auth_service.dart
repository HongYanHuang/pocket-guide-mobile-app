import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:pocket_guide_mobile/services/storage_service.dart';
import 'package:pocket_guide_mobile/services/api_service.dart';
import 'package:pocket_guide_mobile/models/user_model.dart';
import 'package:pocket_guide_api/pocket_guide_api.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();

  // Google Sign-In for mobile (native SDK)
  // On iOS, reads configuration from GoogleService-Info.plist automatically
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
  );

  // For web mode: use http://localhost redirect
  // For mobile: use custom URL scheme (pocketguide://)
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
      if (kIsWeb) {
        // For web: use OAuth flow with FlutterWebAuth2
        return await _loginWeb();
      } else {
        // For mobile: use native Google Sign-In
        return await _loginMobile();
      }
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // Mobile login using Google Sign-In SDK
  Future<bool> _loginMobile() async {
    try {
      print('🔐 ===== MOBILE GOOGLE SIGN-IN =====');
      print('   Starting native Google Sign-In...');

      // Sign in with Google (native UI)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('❌ User cancelled Google Sign-In');
        return false;
      }

      print('✅ Google Sign-In successful');
      print('   User: ${googleUser.email}');

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final idToken = googleAuth.idToken;
      if (idToken == null) {
        print('❌ Failed to get ID token from Google');
        throw Exception('Failed to get ID token');
      }

      print('✅ Got ID token from Google');
      print('   ID Token (first 20 chars): ${idToken.substring(0, 20)}...');

      // Send ID token to backend for verification and to get our app's tokens
      print('🔐 Sending ID token to backend...');
      final tokenResponse = await _verifyGoogleIdToken(idToken);

      if (tokenResponse == null) {
        print('❌ Backend failed to verify ID token');
        throw Exception('Failed to verify ID token with backend');
      }

      print('✅ Backend verified ID token successfully');

      // Save tokens securely
      await _storageService.saveAccessToken(tokenResponse.accessToken);
      await _storageService.saveRefreshToken(tokenResponse.refreshToken);

      print('✅ Mobile login successful!');
      return true;
    } catch (e) {
      print('❌ Mobile login error: $e');
      // Sign out from Google on error
      await _googleSignIn.signOut();
      return false;
    }
  }

  // Web login using OAuth flow (FlutterWebAuth2)
  Future<bool> _loginWeb() async {
    // This is for web platform - keep existing web OAuth flow
    throw Exception('Web login not implemented in mobile build');
  }

  // Verify Google ID token with backend
  Future<AuthTokenResponse?> _verifyGoogleIdToken(String idToken) async {
    try {
      // Call backend endpoint to verify ID token and get our app's tokens
      final dio = Dio(BaseOptions(baseUrl: ApiService.baseUrl));
      final response = await dio.post(
        '/auth/client/google/verify-token',
        data: {'id_token': idToken},
      );

      if (response.data == null) {
        return null;
      }

      // Parse response as AuthTokenResponse
      final tokenData = response.data as Map<String, dynamic>;
      return AuthTokenResponse(
        (b) => b
          ..accessToken = tokenData['access_token']
          ..refreshToken = tokenData['refresh_token']
          ..tokenType = tokenData['token_type']
          ..expiresIn = tokenData['expires_in'],
      );
    } catch (e) {
      print('Error verifying ID token: $e');
      return null;
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

      // Sign out from Google Sign-In on mobile
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      print('Error during logout: $e');
    } finally {
      // Always clear local tokens
      await _storageService.clearTokens();
    }
  }
}
