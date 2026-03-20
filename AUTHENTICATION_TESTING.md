# Authentication Testing Guide

## ✅ Implementation Complete

The Google OAuth 2.0 authentication system with PKCE has been fully implemented.

## 📦 What Was Implemented

### 1. Core Services
- **StorageService** (`lib/services/storage_service.dart`)
  - Secure token storage using flutter_secure_storage
  - Platform-specific encryption (Keychain on iOS, EncryptedSharedPreferences on Android)
  - Stores: access token, refresh token, PKCE verifier, OAuth state

- **AuthService** (`lib/services/auth_service.dart`)
  - PKCE generation (code verifier + SHA-256 challenge)
  - Google OAuth login flow
  - Token exchange and refresh
  - Authentication state management
  - Logout with token revocation

- **ApiService** (`lib/services/api_service.dart`)
  - Extended with AuthenticationApi methods
  - Calls backend OAuth endpoints

### 2. UI Components
- **LoginScreen** (`lib/screens/login_screen.dart`)
  - Google Sign In button
  - Loading states
  - Error messages

- **AuthCheckScreen** (in `lib/main.dart`)
  - Splash screen with auth validation
  - Routes to LoginScreen or MainScreen

- **AccountsScreen** (updated in `lib/main.dart`)
  - Logout button with confirmation dialog

### 3. Models
- **User** (`lib/models/user_model.dart`)
  - email, name, picture, role

### 4. Platform Configuration
- **iOS** (`ios/Runner/Info.plist`)
  - Custom URL scheme: `pocketguide://`

- **Android** (`android/app/src/main/AndroidManifest.xml`)
  - Deep link intent filter for OAuth callback

### 5. Dependencies Added
```yaml
flutter_secure_storage: ^9.0.0
flutter_web_auth_2: ^3.0.0
crypto: ^3.0.3
provider: ^6.1.0
```

## 🧪 Testing Checklist

### Prerequisites
1. Backend server running at `http://localhost:8000`
2. Backend configured with Google OAuth credentials
3. OAuth callback URL registered in Google Cloud Console:
   - For iOS simulator: `pocketguide://auth/callback`
   - For Android emulator: `pocketguide://auth/callback`

### Test 1: First Time Login
1. Launch the app (fresh install)
2. Should see AuthCheckScreen (splash) briefly
3. Should navigate to LoginScreen
4. Click "Sign in with Google" button
5. Browser should open with Google OAuth consent screen
6. Select Google account and grant permissions
7. Should redirect back to app
8. Should navigate to MainScreen (home)

**Expected Results:**
- Tokens stored securely
- User authenticated
- Can browse tours

### Test 2: App Restart (Already Logged In)
1. Close app completely
2. Reopen app
3. Should see AuthCheckScreen briefly
4. Should navigate directly to MainScreen (skip login)

**Expected Results:**
- No login required
- User still authenticated

### Test 3: Token Refresh
This is automatic, but to verify:
1. Login successfully
2. Wait 15+ minutes (or manually expire access token in backend)
3. Try to access protected endpoint (e.g., mark POI as visited)
4. Should automatically refresh token
5. Request should succeed

**Expected Results:**
- No visible interruption
- Seamless token refresh

### Test 4: Logout
1. Navigate to Accounts tab
2. Click "Logout"
3. Confirm logout in dialog
4. Should navigate to LoginScreen

**Expected Results:**
- All tokens cleared from secure storage
- Backend session invalidated
- Login screen shown

### Test 5: OAuth Errors
1. Start login flow
2. Deny Google permissions
3. Should return to LoginScreen with error message

**Expected Results:**
- Error displayed to user
- Can retry login

### Test 6: Network Errors
1. Disconnect from internet
2. Try to login
3. Should show appropriate error

**Expected Results:**
- Error message shown
- No app crash

## 🐛 Known Limitations

1. **Google Logo**: The LoginScreen tries to load `assets/google_logo.png` which doesn't exist yet
   - Falls back to generic login icon
   - To fix: Add Google logo to `assets/` folder and update `pubspec.yaml`

2. **Backend URL**: Hardcoded to `http://localhost:8000`
   - Works for development
   - Need to update for production deployment

3. **Token Auto-Refresh**: Currently reactive (on 401 error)
   - Could be improved with proactive refresh timer

4. **User Profile Display**: AccountsScreen only shows logout
   - Could add user info display (name, email, picture)

## 🔍 Debugging

### Enable Detailed Logging
All auth operations print to console. Check:
```bash
# iOS
xcrun simctl spawn booted log stream --level debug

# Android
adb logcat | grep flutter
```

### Common Issues

**Issue**: "OAuth callback not working"
- **Check**: Deep link configuration in Info.plist / AndroidManifest.xml
- **Check**: URL scheme matches `pocketguide://`

**Issue**: "Tokens not persisting"
- **Check**: flutter_secure_storage permissions
- **iOS**: May need to reset simulator/device
- **Android**: Check EncryptedSharedPreferences setup

**Issue**: "Invalid state parameter"
- **Cause**: OAuth state mismatch (CSRF protection)
- **Fix**: Restart login flow

**Issue**: "User not authorized"
- **Check**: Backend whitelist/public signup configuration
- **Check**: User's Google account

## 📱 Testing on Real Devices

### iOS
1. Update bundle identifier in Xcode
2. Update redirect URI in backend config
3. Update redirect URI in Google Cloud Console
4. Build to device: `flutter run -d <device-id>`

### Android
1. Update package name if needed
2. Update redirect URI in backend config
3. Build to device: `flutter run -d <device-id>`

## 🚀 Next Steps

1. **Add User Profile Screen**
   - Display user name, email, picture
   - Show account info

2. **Add Google Logo Asset**
   - Download official Google logo
   - Add to assets folder
   - Update pubspec.yaml

3. **Implement Token Auto-Refresh**
   - Add proactive refresh timer (every 10 min)
   - More reliable than reactive approach

4. **Add Error Recovery**
   - Better error messages
   - Retry mechanisms
   - Offline support

5. **Production Configuration**
   - Environment-based API URLs
   - Production OAuth credentials
   - HTTPS enforcement

## 📄 API Endpoints Used

- `GET /auth/google/login` - Initiate OAuth
- `GET /auth/google/callback` - Exchange code for tokens
- `POST /auth/refresh` - Refresh access token
- `GET /auth/me` - Get current user (requires auth)
- `POST /auth/logout` - Logout and revoke tokens (requires auth)

## 🔐 Security Notes

✅ PKCE implemented (code challenge/verifier)
✅ State parameter for CSRF protection
✅ Secure token storage (platform-specific encryption)
✅ Tokens never logged or exposed
✅ Authorization header properly set/cleared
✅ Logout clears all local tokens

## 📞 Support

For issues:
1. Check backend logs: `uvicorn src.api_server:app --reload`
2. Check frontend logs: `flutter logs`
3. Review `CLIENT_AUTH_API.md` for backend API details
4. Review `LOGIN_IMPLEMENTATION_PLAN.md` for architecture
