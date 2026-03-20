# Login System Implementation Plan

## Status
- Branch: `feature/login-system`
- API Spec: ✅ Fetched (auth endpoints available in api-spec/openapi.json)
- API Client: ⚠️ Needs regeneration (requires Java installation)

## Overview
Implement Google OAuth 2.0 authentication with PKCE for the Pocket Guide mobile app.

## API Endpoints Available
Based on CLIENT_AUTH_API.md:
1. `GET /auth/google/login` - Initiate OAuth flow
2. `GET /auth/google/callback` - Exchange code for tokens
3. `POST /auth/refresh` - Refresh access token
4. `GET /auth/me` - Get current user info
5. `POST /auth/logout` - Logout and revoke tokens

## Token Strategy
- **Access Token**: JWT, 15 min expiry, stored in memory/secure storage
- **Refresh Token**: UUID, 7 days expiry, stored in secure storage
- **PKCE**: Required for security (code challenge/verifier)

## Implementation Steps

### 1. Prerequisites
- [ ] Install Java (required for API client generation)
- [ ] Run `npm run update-api` to regenerate API client with auth endpoints
- [ ] Add Flutter dependencies for OAuth and secure storage

### 2. Flutter Dependencies (pubspec.yaml)
```yaml
dependencies:
  # Secure storage for tokens
  flutter_secure_storage: ^9.0.0

  # OAuth / Web authentication
  flutter_web_auth_2: ^3.0.0

  # State management (if needed)
  provider: ^6.1.0

  # HTTP client (already have dio)
  dio: ^5.4.0

  # Crypto for PKCE
  crypto: ^3.0.3
```

### 3. Project Structure
```
lib/
├── services/
│   ├── api_service.dart (existing)
│   ├── auth_service.dart (NEW - OAuth flow, token management)
│   └── storage_service.dart (NEW - secure token storage)
├── models/
│   └── user_model.dart (NEW - user data model)
├── screens/
│   ├── login_screen.dart (NEW)
│   └── ... (existing screens)
└── main.dart (UPDATE - add auth check on startup)
```

### 4. Core Components to Build

#### A. StorageService (lib/services/storage_service.dart)
**Purpose**: Securely store and retrieve tokens
```dart
class StorageService {
  final FlutterSecureStorage _storage;

  Future<void> saveAccessToken(String token);
  Future<String?> getAccessToken();
  Future<void> saveRefreshToken(String token);
  Future<String?> getRefreshToken();
  Future<void> clearTokens();
}
```

#### B. AuthService (lib/services/auth_service.dart)
**Purpose**: Handle OAuth flow, PKCE, token refresh
```dart
class AuthService {
  final ApiService _apiService;
  final StorageService _storageService;

  // PKCE helpers
  String _generateCodeVerifier();
  Future<String> _generateCodeChallenge(String verifier);

  // OAuth flow
  Future<void> login();
  Future<void> handleCallback(String code, String state, String verifier);
  Future<void> logout();

  // Token management
  Future<bool> refreshAccessToken();
  Future<bool> isAuthenticated();
  Future<User?> getCurrentUser();
}
```

#### C. User Model (lib/models/user_model.dart)
```dart
class User {
  final String email;
  final String name;
  final String? picture;
  final String role;
}
```

#### D. Login Screen (lib/screens/login_screen.dart)
**UI Components**:
- App logo/branding
- "Sign in with Google" button
- Loading state during OAuth
- Error messages

### 5. OAuth Flow Implementation

#### Step 1: User clicks "Sign in with Google"
```dart
// In AuthService
Future<void> login() async {
  // 1. Generate PKCE
  final codeVerifier = _generateCodeVerifier();
  final codeChallenge = await _generateCodeChallenge(codeVerifier);

  // 2. Store verifier for callback
  await _storageService.saveCodeVerifier(codeVerifier);

  // 3. Get Google OAuth URL from backend
  final response = await _apiService.getGoogleLoginUrl(
    redirectUri: 'yourapp://auth/callback',
    codeChallenge: codeChallenge,
  );

  // 4. Open browser for OAuth
  final result = await FlutterWebAuth2.authenticate(
    url: response.authUrl,
    callbackUrlScheme: 'yourapp',
  );

  // 5. Extract code from callback URL
  final code = Uri.parse(result).queryParameters['code'];
  final state = Uri.parse(result).queryParameters['state'];

  // 6. Exchange code for tokens
  await handleCallback(code, state, codeVerifier);
}
```

#### Step 2: Exchange authorization code for tokens
```dart
Future<void> handleCallback(String code, String state, String verifier) async {
  final response = await _apiService.exchangeCodeForTokens(
    code: code,
    state: state,
    codeVerifier: verifier,
  );

  // Save tokens securely
  await _storageService.saveAccessToken(response.accessToken);
  await _storageService.saveRefreshToken(response.refreshToken);
}
```

#### Step 3: Auto-refresh tokens
```dart
// In ApiService - intercept 401 responses
dio.interceptors.add(InterceptorsWrapper(
  onError: (error, handler) async {
    if (error.response?.statusCode == 401) {
      // Try to refresh token
      final refreshed = await _authService.refreshAccessToken();
      if (refreshed) {
        // Retry original request with new token
        final token = await _storageService.getAccessToken();
        error.requestOptions.headers['Authorization'] = 'Bearer $token';
        return handler.resolve(await dio.fetch(error.requestOptions));
      } else {
        // Logout if refresh fails
        await _authService.logout();
      }
    }
    return handler.next(error);
  },
));
```

### 6. Update Main App (lib/main.dart)
```dart
class PocketGuideApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder<bool>(
        future: AuthService().isAuthenticated(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SplashScreen();
          }

          if (snapshot.data == true) {
            return MainScreen(); // Existing app
          } else {
            return LoginScreen(); // New login screen
          }
        },
      ),
    );
  }
}
```

### 7. Configuration
**Deep Link Setup** (for OAuth callback):

**iOS (ios/Runner/Info.plist)**:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>yourapp</string>
    </array>
  </dict>
</array>
```

**Android (android/app/src/main/AndroidManifest.xml)**:
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="yourapp" />
</intent-filter>
```

### 8. Testing Checklist
- [ ] Login flow works end-to-end
- [ ] Tokens stored securely
- [ ] Access token auto-refreshes before expiry
- [ ] 401 responses trigger token refresh
- [ ] Logout clears all tokens
- [ ] App checks auth on startup
- [ ] Deep links work for OAuth callback

### 9. Security Considerations
✅ Always use PKCE (code challenge/verifier)
✅ Store tokens in secure storage (not SharedPreferences)
✅ Never log tokens
✅ Validate state parameter to prevent CSRF
✅ Use HTTPS in production
✅ Clear tokens on logout

## Next Steps
1. Install Java to regenerate API client
2. Add Flutter dependencies
3. Create StorageService
4. Create AuthService with PKCE
5. Create LoginScreen UI
6. Update main.dart with auth check
7. Configure deep links for iOS/Android
8. Test OAuth flow

## References
- [CLIENT_AUTH_API.md](./CLIENT_AUTH_API.md) - Backend auth API documentation
- Flutter Secure Storage: https://pub.dev/packages/flutter_secure_storage
- Flutter Web Auth 2: https://pub.dev/packages/flutter_web_auth_2
