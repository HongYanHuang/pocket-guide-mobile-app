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
import 'package:url_launcher/url_launcher.dart';

class AuthService {
  final StorageService _storageService = StorageService();
  final ApiService _apiService = ApiService();

  // Google Sign-In for mobile (native SDK)
  // On iOS, reads configuration from GoogleService-Info.plist automatically
  // Lazy-initialized to avoid web crash (GoogleSignIn only needed for mobile)
  GoogleSignIn? _googleSignIn;

  // Get GoogleSignIn instance (mobile only)
  GoogleSignIn _getGoogleSignIn() {
    if (kIsWeb) {
      throw Exception('GoogleSignIn should not be used on web platform');
    }
    return _googleSignIn ??= GoogleSignIn(
      scopes: ['email', 'profile', 'openid'],
    );
  }

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
      print('');
      print('═══════════════════════════════════════════════════════════════');
      print('🔐 WEB GOOGLE OAUTH - CALLBACK PHASE');
      print('═══════════════════════════════════════════════════════════════');
      print('');

      print('✅ Step 1: Received callback from Google');
      print('   Code (first 20): ${code.length > 20 ? code.substring(0, 20) : code}...');
      print('   Code length: ${code.length} characters');
      print('   State (first 20): ${state.length > 20 ? state.substring(0, 20) : state}...');
      print('   State length: ${state.length} characters');
      print('');

      // Validate state to prevent CSRF
      print('✅ Step 2: Validating state (CSRF protection)');
      final savedState = await _storageService.getOAuthState();

      if (savedState == null) {
        print('❌ ERROR: No saved state found in storage!');
        print('   This could mean:');
        print('   1. Storage was cleared between login initiation and callback');
        print('   2. OAuth flow was not initiated properly');
        print('   3. Browser storage is not working correctly');
        throw Exception('No saved state found - OAuth flow not initiated properly');
      }

      print('   Saved state (first 20): ${savedState.substring(0, 20)}...');
      print('   Received state (first 20): ${state.substring(0, 20)}...');

      if (savedState != state) {
        print('❌ ERROR: State mismatch!');
        print('   Saved:    $savedState');
        print('   Received: $state');
        print('   This indicates a possible CSRF attack or storage issue!');
        throw Exception('Invalid state parameter - possible CSRF attack');
      }
      print('   ✅ State matches! CSRF check passed.');
      print('');

      // Get code verifier
      print('✅ Step 3: Retrieving PKCE code verifier from storage');
      final codeVerifier = await _storageService.getCodeVerifier();

      if (codeVerifier == null) {
        print('❌ ERROR: No code verifier found in storage!');
        print('   This should have been saved during login initiation.');
        throw Exception('Missing PKCE code verifier');
      }

      print('   Code verifier (first 20): ${codeVerifier.substring(0, 20)}...');
      print('   Code verifier length: ${codeVerifier.length} characters');
      print('');

      // Exchange code for tokens
      print('═══════════════════════════════════════════════════════════════');
      print('📤 Step 4: Exchanging authorization code for tokens');
      print('═══════════════════════════════════════════════════════════════');
      print('   Calling: ${ApiService.baseUrl}/auth/client/google/callback');
      print('   Parameters:');
      print('     - code: ${code.substring(0, 30)}...');
      print('     - state: ${state.substring(0, 30)}...');
      print('     - code_verifier: ${codeVerifier.substring(0, 30)}...');
      print('');

      await _handleCallback(code, state, codeVerifier);

      print('');
      print('✅ Step 5: Token exchange successful!');
      print('   Access token and refresh token have been saved.');
      print('');

      // Clean up temporary storage
      await _storageService.deleteCodeVerifier();
      await _storageService.deleteOAuthState();
      print('✅ Step 6: Cleaned up temporary OAuth storage');
      print('');
      print('═══════════════════════════════════════════════════════════════');
      print('✅ WEB OAUTH LOGIN COMPLETE!');
      print('═══════════════════════════════════════════════════════════════');
      print('');

      return true;
    } catch (e, stackTrace) {
      print('');
      print('═══════════════════════════════════════════════════════════════');
      print('❌ CALLBACK ERROR');
      print('═══════════════════════════════════════════════════════════════');
      print('Error: $e');
      print('');
      print('Stack trace:');
      print(stackTrace);
      print('═══════════════════════════════════════════════════════════════');
      print('');

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
      final GoogleSignInAccount? googleUser = await _getGoogleSignIn().signIn();

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
      await _getGoogleSignIn().signOut();
      return false;
    }
  }

  // Web login using OAuth flow (for web platform)
  Future<bool> _loginWeb() async {
    try {
      print('');
      print('═══════════════════════════════════════════════════════════════');
      print('🔐 WEB GOOGLE OAUTH - INITIATION PHASE');
      print('═══════════════════════════════════════════════════════════════');
      print('');

      // Generate PKCE code verifier and challenge
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      final state = _generateState();

      print('✅ Step 1: Generated security parameters');
      print('   Code Verifier (first 20): ${codeVerifier.substring(0, 20)}...');
      print('   Code Challenge (first 20): ${codeChallenge.substring(0, 20)}...');
      print('   State (first 20): ${state.substring(0, 20)}...');
      print('');

      // Save for later verification
      await _storageService.saveCodeVerifier(codeVerifier);
      await _storageService.saveOAuthState(state);
      print('✅ Step 2: Saved to storage');
      print('');

      // Get redirect URI (current origin + /auth/callback)
      final redirectUri = '${Uri.base.origin}/auth/callback';
      print('✅ Step 3: Determined redirect URI');
      print('   Current origin: ${Uri.base.origin}');
      print('   Redirect URI: $redirectUri');
      print('   ⚠️  This MUST be whitelisted in Google OAuth Web Client!');
      print('');

      print('📤 Step 4: Calling backend /auth/client/google/login');
      print('   Endpoint: ${ApiService.baseUrl}/auth/client/google/login');
      print('   Parameters:');
      print('     - redirect_uri: $redirectUri');
      print('     - code_challenge: ${codeChallenge.substring(0, 30)}...');
      print('');

      // Call backend to initiate OAuth and get Google auth URL
      final loginData = await _apiService.initiateGoogleLogin(
        redirectUri: redirectUri,
        codeChallenge: codeChallenge,
      );

      if (loginData == null) {
        print('❌ ERROR: Backend returned null');
        throw Exception('Backend returned null response');
      }

      if (loginData['auth_url'] == null) {
        print('❌ ERROR: No auth_url in backend response');
        print('   Response keys: ${loginData.keys.toList()}');
        print('   Full response: $loginData');
        throw Exception('No auth_url in backend response');
      }

      final authUrl = loginData['auth_url'] as String;
      print('✅ Step 5: Received auth URL from backend');
      print('');
      print('═══════════════════════════════════════════════════════════════');
      print('📥 GOOGLE OAUTH URL BREAKDOWN');
      print('═══════════════════════════════════════════════════════════════');

      // Parse and display URL parameters
      final googleUri = Uri.parse(authUrl);
      print('Base URL: ${googleUri.scheme}://${googleUri.host}${googleUri.path}');
      print('');
      print('Query Parameters:');
      googleUri.queryParameters.forEach((key, value) {
        if (key == 'client_id') {
          print('  ✅ client_id: ${value.substring(0, 20)}... (${value.length} chars)');
          print('     ⚠️  This should be Web OAuth client, NOT iOS client!');
        } else if (key == 'redirect_uri') {
          print('  ${value == redirectUri ? "✅" : "❌"} redirect_uri: $value');
          if (value != redirectUri) {
            print('     ❌ MISMATCH! Expected: $redirectUri');
          }
        } else if (key == 'response_type') {
          print('  ${value == "code" ? "✅" : "❌"} response_type: $value');
          if (value != 'code') {
            print('     ❌ Should be "code" for authorization code flow!');
          }
        } else if (key == 'scope') {
          print('  ✅ scope: $value');
        } else if (key == 'state') {
          print('  ✅ state: ${value.substring(0, 20)}...');
        } else if (key == 'code_challenge') {
          print('  ✅ code_challenge: ${value.substring(0, 20)}...');
        } else if (key == 'code_challenge_method') {
          print('  ${value == "S256" ? "✅" : "❌"} code_challenge_method: $value');
        } else {
          print('  • $key: $value');
        }
      });
      print('');
      print('Full URL:');
      print(authUrl);
      print('');
      print('═══════════════════════════════════════════════════════════════');
      print('🚀 Step 6: Redirecting to Google...');
      print('═══════════════════════════════════════════════════════════════');
      print('');

      // For web: Redirect the entire page to Google OAuth
      // Google will redirect back to /auth/callback after authentication
      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          webOnlyWindowName: '_self', // Redirect in same tab
        );
      } else {
        print('❌ ERROR: Could not launch URL');
        throw Exception('Could not launch auth URL');
      }

      // Note: This code won't execute because the page redirects
      // The AuthCallbackScreen will handle the callback when Google redirects back
      return true;
    } catch (e, stackTrace) {
      print('');
      print('═══════════════════════════════════════════════════════════════');
      print('❌ WEB LOGIN ERROR');
      print('═══════════════════════════════════════════════════════════════');
      print('Error: $e');
      print('Stack trace:');
      print(stackTrace);
      print('═══════════════════════════════════════════════════════════════');
      print('');

      // Clean up on error
      await _storageService.deleteCodeVerifier();
      await _storageService.deleteOAuthState();
      return false;
    }
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
        await _getGoogleSignIn().signOut();
      }
    } catch (e) {
      print('Error during logout: $e');
    } finally {
      // Always clear local tokens
      await _storageService.clearTokens();
    }
  }
}
