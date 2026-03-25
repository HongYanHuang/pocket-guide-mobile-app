# Web Development Setup

## Running Flutter Web for Development

To enable Google OAuth login on Chrome, you **must** run Flutter web on a **fixed port** (not a random port).

### Commands

```bash
# Run Flutter web on fixed port 8080
flutter run -d chrome --web-port=8080

# Or port 3000 if you prefer
flutter run -d chrome --web-port=3000
```

### Why?

- Flutter web dev server normally uses **random ports** (like localhost:65263)
- Google OAuth requires **exact redirect URIs** to be whitelisted
- We can't whitelist random ports, so we need a **fixed port**

## Google OAuth Web Client Configuration

### 1. Create Web OAuth Client

Go to [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials

**Create OAuth 2.0 Client ID** → Select: **Web application**

### 2. Configure Authorized URIs

**Authorized JavaScript origins:**
```
http://localhost:8080
```

**Authorized redirect URIs:**
```
http://localhost:8080/auth/callback
```

### 3. Give Credentials to Backend

Download the web client credentials JSON and give to backend developer.

Backend needs to use:
- **Web client credentials** when `redirect_uri` contains `localhost`
- **iOS client credentials** when verifying mobile ID tokens

## Testing Web Login

1. Make sure backend is running on `http://localhost:8000`
2. Run Flutter web: `flutter run -d chrome --web-port=8080`
3. Open browser, click "Login with Google"
4. Check console output:
   ```
   🔐 ===== WEB GOOGLE OAUTH =====
      Starting web OAuth flow...
   ✅ Generated PKCE and state
   ✅ Saved to storage
      Redirect URI: http://localhost:8080/auth/callback
      ⚠️  Make sure this URL is whitelisted in Google OAuth Web Client!
   ```
5. Should redirect to Google and back successfully

## Common Issues

### Error: invalid_client (401)

**Cause:** Google OAuth web client doesn't have the redirect URI whitelisted.

**Fix:** Add `http://localhost:8080/auth/callback` to Google OAuth Web Client authorized redirect URIs.

### CORS Error

**Cause:** Backend doesn't allow requests from localhost.

**Fix:** Backend needs CORS configuration:
```python
allow_origins=["http://localhost:8080", "http://localhost:3000"]
```

### Wrong Port

If you see "Redirect URI: http://localhost:65263/auth/callback" (random port), you forgot to use `--web-port` flag.

**Fix:** Restart with: `flutter run -d chrome --web-port=8080`
