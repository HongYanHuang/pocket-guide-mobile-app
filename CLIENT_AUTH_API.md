# Client-Side Authentication API Guide

This guide explains how to integrate Google OAuth 2.0 authentication into your client-side application (web or mobile) using the Pocket Guide API.

## Quick Start

**For developers building client apps (web/mobile):**

1. **Configure backend CORS** - Add your app origin to `config.yaml`:
   ```yaml
   cors:
     allowed_origins:
       - "http://localhost:65263"  # Your client app
   ```

2. **Set up Google OAuth** - Add redirect URI: `http://localhost:65263/auth/callback`

3. **Use client-specific endpoints:**
   - Login: `GET /auth/client/google/login`
   - Callback: `GET /auth/client/google/callback`

4. **Enable public signup** in `config.yaml`:
   ```yaml
   allow_public_signup: true
   ```

5. **Start backend:** `uvicorn src.api_server:app --reload`

6. **Implement OAuth flow** (see [Step-by-Step Implementation](#step-by-step-implementation))

**You'll get:** `client_user` role with scopes `[client_app, read_tours, user_data]`

---

## Table of Contents
- [Overview](#overview)
- [Prerequisites & Setup](#prerequisites--setup)
- [Authentication Flow](#authentication-flow)
- [API Endpoints](#api-endpoints)
- [Step-by-Step Implementation](#step-by-step-implementation)
- [Token Management](#token-management)
- [API Usage](#api-usage)
- [Error Handling](#error-handling)
- [Security Best Practices](#security-best-practices)

---

## Overview

### Authentication Method
- **OAuth 2.0** with **PKCE** (Proof Key for Code Exchange)
- **Provider**: Google OAuth
- **Token Types**: JWT access token (15 min) + UUID refresh token (7 days)

### User Types
- **Backstage Users**: Pre-configured admins, editors, viewers (whitelist only)
- **Client App Users**: Regular users (auto-registered on first login if `allow_public_signup: true`)

### Base URL
```
Production: https://api.yourapp.com
Development: http://localhost:8000
```

---

## Prerequisites & Setup

### 1. Google OAuth Configuration

**Create OAuth 2.0 Client ID:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create OAuth 2.0 Client ID (Web Application)
3. Configure authorized origins and redirect URIs:

**Authorized JavaScript Origins:**
```
http://localhost:8000          (Backend API)
http://localhost:5173          (Backstage admin - optional)
http://localhost:65263         (Your client app)
https://yourapp.com            (Production client app)
```

**Authorized Redirect URIs:**
```
http://localhost:8000/auth/google/callback    (Backend callback)
http://localhost:65263/auth/callback          (Client app callback)
https://yourapp.com/auth/callback             (Production callback)
```

4. Save the `Client ID` and `Client Secret`

---

### 2. Backend Configuration

**Enable CORS for Your Client App:**

The backend must allow cross-origin requests from your client app domain.

**Update `config.yaml`:**
```yaml
authentication:
  # Enable public signup for client app
  allow_public_signup: true

  # CORS Configuration
  cors:
    allowed_origins:
      - "http://localhost:8000"      # Backend API
      - "http://localhost:5173"      # Backstage (optional)
      - "http://localhost:65263"     # Your client app (REQUIRED)
      # For production:
      # - "https://yourapp.com"
```

**Or using environment variables:**

Create `.env`:
```bash
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
JWT_SECRET_KEY=your-32-char-secret
CORS_ORIGINS=http://localhost:8000,http://localhost:65263
```

**⚠️ IMPORTANT:** Without CORS configuration, your client app will get errors like:
```
Access to fetch at 'http://localhost:8000/auth/client/google/login'
from origin 'http://localhost:65263' has been blocked by CORS policy
```

---

### 3. Verify CORS is Working

Test CORS from your client app:

```javascript
// Run this in your client app console
fetch('http://localhost:8000/auth/me', {
  headers: { 'Authorization': 'Bearer test' }
})
.then(r => console.log('CORS OK'))
.catch(e => console.error('CORS Error:', e))
```

**Expected:**
- ✅ `401 Unauthorized` (expected - no valid token)
- ❌ `CORS Error` → Backend CORS not configured for your origin

---

### 4. Start Backend with CORS Enabled

```bash
# Make sure config.yaml includes your client app origin
uvicorn src.api_server:app --reload --host 0.0.0.0 --port 8000
```

**Verify logs show CORS configuration:**
```
INFO:     Configuration loaded successfully
INFO:     CORS allowed origins: ['http://localhost:8000', 'http://localhost:65263']
INFO:     Application startup complete.
```

---

## Authentication Flow

```
┌─────────────────────────┐
│ Your Client App         │
│ (localhost:65263)       │
└──────────┬──────────────┘
           │
           │ 1. Generate PKCE challenge
           │ 2. GET /auth/client/google/login
           │
           v
┌─────────────────────────┐
│ Backend API             │
│ (localhost:8000)        │
└──────────┬──────────────┘
           │
           │ 3. Returns Google OAuth URL
           │
           v
┌─────────────────────────┐
│ Google OAuth            │
│ (User consents)         │
└──────────┬──────────────┘
           │
           │ 4. Redirects to your callback URL
           │    with authorization code
           │
           v
┌─────────────────────────┐
│ Your Client App         │
│ /auth/callback          │
└──────────┬──────────────┘
           │
           │ 5. GET /auth/client/google/callback
           │    with code + PKCE verifier
           │
           v
┌─────────────────────────┐
│ Backend API             │
│ Returns tokens          │
└──────────┬──────────────┘
           │
           │ access_token (JWT, 15 min)
           │ refresh_token (UUID, 7 days)
           │ role: client_user
           │ scopes: [client_app, read_tours, user_data]
           │
           v
┌─────────────────────────┐
│ Your Client App         │
│ (Authenticated)         │
└─────────────────────────┘
```

---

## API Endpoints

**IMPORTANT:** Use client-specific endpoints for better security:
- **Backstage**: `/auth/backstage/google/*`
- **Client App**: `/auth/client/google/*`

The backend will enforce role assignment based on which endpoint you use - clients cannot spoof their type.

### 1. Initiate Login

#### For Client App (Recommended)

**GET** `/auth/client/google/login`

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `redirect_uri` | string | Yes | Your client app callback URL |
| `code_challenge` | string | Yes | PKCE code challenge (Base64-URL encoded SHA-256 hash) |

**Response:**
```json
{
  "auth_url": "https://accounts.google.com/o/oauth2/v2/auth?client_id=...",
  "state": "uuid-v4-string"
}
```

**Example:**
```bash
curl "http://localhost:8000/auth/client/google/login?redirect_uri=http://localhost:65263/auth/callback&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
```

---

#### For Backstage Admin Panel

**GET** `/auth/backstage/google/login`

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `redirect_uri` | string | Yes | Backstage callback URL (must match Google Console) |
| `code_challenge` | string | Yes | PKCE code challenge (Base64-URL encoded SHA-256 hash) |

**Response:**
```json
{
  "auth_url": "https://accounts.google.com/o/oauth2/v2/auth?client_id=...",
  "state": "uuid-v4-string"
}
```

**Example:**
```bash
curl "http://localhost:8000/auth/backstage/google/login?redirect_uri=http://localhost:5173/auth/callback&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
```

---

---

### 2. Exchange Code for Tokens

#### For Client App (Recommended)

**GET** `/auth/client/google/callback`

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `code` | string | Yes | Authorization code from Google |
| `state` | string | Yes | State parameter from step 1 |
| `code_verifier` | string | Yes | PKCE code verifier (original random string) |

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "550e8400-e29b-41d4-a716-446655440000",
  "token_type": "bearer",
  "expires_in": 900
}
```

**Example:**
```bash
curl "http://localhost:8000/auth/client/google/callback?code=4/0AfJoh...&state=abc-123&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
```

---

#### For Backstage Admin Panel

**GET** `/auth/backstage/google/callback`

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `code` | string | Yes | Authorization code from Google |
| `state` | string | Yes | State parameter from step 1 |
| `code_verifier` | string | Yes | PKCE code verifier (original random string) |

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "550e8400-e29b-41d4-a716-446655440000",
  "token_type": "bearer",
  "expires_in": 900
}
```

**Example:**
```bash
curl "http://localhost:8000/auth/google/callback?code=4/0AfJoh...&state=abc-123&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
```

---

### 3. Refresh Access Token

**POST** `/auth/refresh`

**Headers:**
```
Content-Type: application/json
```

**Body:**
```json
{
  "refresh_token": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "550e8400-e29b-41d4-a716-446655440000",
  "token_type": "bearer",
  "expires_in": 900
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"550e8400-e29b-41d4-a716-446655440000"}'
```

---

### 4. Get Current User Info

**GET** `/auth/me`

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:**
```json
{
  "email": "user@example.com",
  "name": "John Doe",
  "picture": "https://lh3.googleusercontent.com/...",
  "role": "client_user"
}
```

**Example:**
```bash
curl http://localhost:8000/auth/me \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

### 5. Logout

**POST** `/auth/logout`

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Body:**
```json
{
  "refresh_token": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response:**
```json
{
  "message": "Logged out"
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/auth/logout \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":"550e8400-e29b-41d4-a716-446655440000"}'
```

---

## Step-by-Step Implementation

### Step 1: Generate PKCE Code Verifier and Challenge

PKCE (Proof Key for Code Exchange) prevents authorization code interception attacks.

**JavaScript/TypeScript:**
```javascript
// Generate random code verifier
function generateCodeVerifier() {
  const array = new Uint8Array(32)
  crypto.getRandomValues(array)
  return base64UrlEncode(array)
}

// Generate code challenge from verifier
async function generateCodeChallenge(verifier) {
  const encoder = new TextEncoder()
  const data = encoder.encode(verifier)
  const hash = await crypto.subtle.digest('SHA-256', data)
  return base64UrlEncode(new Uint8Array(hash))
}

// Base64-URL encoding (no padding)
function base64UrlEncode(array) {
  return btoa(String.fromCharCode.apply(null, array))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}
```

**React Native / Mobile:**
```javascript
import * as Crypto from 'expo-crypto'

async function generateCodeVerifier() {
  const randomBytes = await Crypto.getRandomBytesAsync(32)
  return base64UrlEncode(randomBytes)
}

async function generateCodeChallenge(verifier) {
  const hash = await Crypto.digestStringAsync(
    Crypto.CryptoDigestAlgorithm.SHA256,
    verifier
  )
  return hash
}
```

---

### Step 2: Initiate Login Flow

```javascript
async function login() {
  // 1. Generate PKCE parameters
  const codeVerifier = generateCodeVerifier()
  const codeChallenge = await generateCodeChallenge(codeVerifier)

  // 2. Store code verifier (needed for callback)
  sessionStorage.setItem('pkce_code_verifier', codeVerifier)

  // 3. Get Google OAuth URL (use client-specific endpoint)
  const redirectUri = `${window.location.origin}/auth/callback`
  const response = await fetch(
    `http://localhost:8000/auth/client/google/login?redirect_uri=${redirectUri}&code_challenge=${codeChallenge}`
  )
  const { auth_url, state } = await response.json()

  // 4. Redirect user to Google
  window.location.href = auth_url
}
```

---

### Step 3: Handle OAuth Callback

```javascript
// This runs on your callback page (e.g., /auth/callback)
async function handleCallback() {
  // 1. Get URL parameters
  const urlParams = new URLSearchParams(window.location.search)
  const code = urlParams.get('code')
  const state = urlParams.get('state')

  if (!code || !state) {
    throw new Error('Missing authorization code or state')
  }

  // 2. Retrieve stored code verifier
  const codeVerifier = sessionStorage.getItem('pkce_code_verifier')
  if (!codeVerifier) {
    throw new Error('Missing PKCE code verifier')
  }

  // 3. Exchange code for tokens (use client-specific endpoint)
  const response = await fetch(
    `http://localhost:8000/auth/client/google/callback?code=${code}&state=${state}&code_verifier=${codeVerifier}`
  )
  const tokens = await response.json()

  // 4. Store tokens
  sessionStorage.setItem('access_token', tokens.access_token)
  localStorage.setItem('refresh_token', tokens.refresh_token)

  // 5. Clean up
  sessionStorage.removeItem('pkce_code_verifier')

  // 6. Redirect to app
  window.location.href = '/'
}
```

---

## Token Management

### Storage Strategy

| Token Type | Storage Location | Lifetime | Purpose |
|------------|------------------|----------|---------|
| Access Token | `sessionStorage` | 15 minutes | API authentication |
| Refresh Token | `localStorage` | 7 days | Renew access token |

**Why this approach?**
- **sessionStorage**: Cleared when tab closes (more secure for short-lived tokens)
- **localStorage**: Persists across sessions (allows "remember me" functionality)

---

### Automatic Token Refresh

**Option 1: Proactive Refresh (Recommended)**

Refresh access token every 10 minutes to prevent expiration during API calls.

```javascript
let refreshInterval = null

function startTokenRefresh() {
  // Refresh every 10 minutes (before 15-minute expiry)
  refreshInterval = setInterval(async () => {
    const success = await refreshAccessToken()
    if (!success) {
      console.warn('Token refresh failed, logging out')
      logout()
    }
  }, 10 * 60 * 1000) // 10 minutes
}

function stopTokenRefresh() {
  if (refreshInterval) {
    clearInterval(refreshInterval)
    refreshInterval = null
  }
}

async function refreshAccessToken() {
  try {
    const refreshToken = localStorage.getItem('refresh_token')
    if (!refreshToken) return false

    const response = await fetch('http://localhost:8000/auth/refresh', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refreshToken })
    })

    const tokens = await response.json()
    sessionStorage.setItem('access_token', tokens.access_token)
    return true
  } catch (error) {
    console.error('Token refresh failed:', error)
    return false
  }
}
```

---

**Option 2: Reactive Refresh**

Refresh only when API returns 401 Unauthorized.

```javascript
async function apiCall(url, options = {}) {
  // Add access token to request
  const accessToken = sessionStorage.getItem('access_token')
  options.headers = {
    ...options.headers,
    'Authorization': `Bearer ${accessToken}`
  }

  let response = await fetch(url, options)

  // If 401, try refreshing token and retry
  if (response.status === 401) {
    const refreshed = await refreshAccessToken()
    if (!refreshed) {
      logout()
      throw new Error('Authentication failed')
    }

    // Retry with new token
    const newAccessToken = sessionStorage.getItem('access_token')
    options.headers['Authorization'] = `Bearer ${newAccessToken}`
    response = await fetch(url, options)
  }

  return response.json()
}
```

---

## API Usage

### Making Authenticated Requests

All protected endpoints require the `Authorization` header with your access token.

```javascript
async function fetchUserData() {
  const accessToken = sessionStorage.getItem('access_token')

  const response = await fetch('http://localhost:8000/my/visited', {
    headers: {
      'Authorization': `Bearer ${accessToken}`
    }
  })

  return await response.json()
}
```

---

### Example: Mark POI as Visited

```javascript
async function markPOIVisited(city, poiId) {
  const accessToken = sessionStorage.getItem('access_token')

  const response = await fetch(
    `http://localhost:8000/my/visited/${city}/${poiId}`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    }
  )

  return await response.json()
}

// Usage
await markPOIVisited('paris', 'eiffel-tower')
```

---

## Error Handling

### Common Error Responses

**401 Unauthorized**
```json
{
  "detail": "Token expired"
}
```
**Action**: Refresh access token or redirect to login.

---

**403 Forbidden**
```json
{
  "detail": "Not authorized"
}
```
**Action**: User doesn't have required role/scope. Show access denied message.

---

**400 Bad Request**
```json
{
  "detail": "Invalid state"
}
```
**Action**: Restart OAuth flow.

---

### Error Handling Example

```javascript
async function makeRequest(url, options = {}) {
  try {
    const response = await fetch(url, options)

    if (!response.ok) {
      const error = await response.json()

      switch (response.status) {
        case 401:
          // Try refresh
          const refreshed = await refreshAccessToken()
          if (refreshed) {
            return makeRequest(url, options) // Retry
          } else {
            logout()
            throw new Error('Session expired, please login again')
          }

        case 403:
          throw new Error('Access denied: ' + error.detail)

        case 400:
          throw new Error('Bad request: ' + error.detail)

        default:
          throw new Error(error.detail || 'Request failed')
      }
    }

    return await response.json()
  } catch (error) {
    console.error('API error:', error)
    throw error
  }
}
```

---

## Security Best Practices

### 1. Use Client-Specific Endpoints
**Always use `/auth/client/google/*` endpoints** for client apps, not the generic `/auth/google/*` endpoints.

**Why?**
- ✅ Backend enforces client type based on endpoint (cannot be spoofed)
- ✅ Prevents malicious clients from pretending to be backstage
- ✅ Explicit intent - clear which app is authenticating
- ✅ Better security logging

**Bad (less secure):**
```javascript
// Client could change redirect_uri to spoof backstage
fetch('/auth/google/login?redirect_uri=http://localhost:5173/callback')
```

**Good (secure):**
```javascript
// Endpoint determines client type - cannot be spoofed
fetch('/auth/client/google/login?redirect_uri=http://localhost:65263/callback')
```

### 2. Always Use PKCE
Never skip PKCE code challenge/verifier - it prevents authorization code interception.

### 2. Validate Redirect URIs
Ensure your callback URL is registered in Google Cloud Console:
```
Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Client ID
→ Authorized redirect URIs
```

**Required Redirect URIs for Development:**
- Backend callback: `http://localhost:8000/auth/google/callback`
- Backstage admin: `http://localhost:5173/auth/callback`
- Client web app: `http://localhost:65263/auth/callback` (or your dev server port)

**Required Origins:**
- `http://localhost:8000`
- `http://localhost:5173`
- `http://localhost:65263`

### 3. Token Storage
- **Never** store tokens in cookies without `HttpOnly` flag
- **Never** expose tokens in URLs
- **Always** use `sessionStorage` for access tokens
- Use `localStorage` only for refresh tokens (if you need persistence)

### 4. Configure CORS Properly

**CRITICAL:** Backend must allow your client app origin.

**Development:**
```yaml
# config.yaml
authentication:
  cors:
    allowed_origins:
      - "http://localhost:65263"  # Your client app
```

**Production:**
```yaml
authentication:
  cors:
    allowed_origins:
      - "https://yourapp.com"      # Production domain
      - "https://www.yourapp.com"  # www subdomain
```

**Test CORS is working:**
```javascript
// Run from your client app
fetch('http://localhost:8000/auth/me')
  .then(r => console.log('✅ CORS configured correctly'))
  .catch(e => console.error('❌ CORS error:', e))
```

### 5. HTTPS Only (Production)
In production, **always** use HTTPS:
```javascript
const API_BASE_URL = process.env.NODE_ENV === 'production'
  ? 'https://api.yourapp.com'
  : 'http://localhost:8000'
```

### 5. Logout Cleanup
Clear all tokens and session data on logout:
```javascript
async function logout() {
  try {
    const refreshToken = localStorage.getItem('refresh_token')
    const accessToken = sessionStorage.getItem('access_token')

    if (refreshToken && accessToken) {
      await fetch('http://localhost:8000/auth/logout', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ refresh_token: refreshToken })
      })
    }
  } catch (error) {
    console.error('Logout error:', error)
  } finally {
    // Always clear local storage
    sessionStorage.removeItem('access_token')
    localStorage.removeItem('refresh_token')
    window.location.href = '/login'
  }
}
```

### 6. State Parameter Validation
Always verify the `state` parameter matches to prevent CSRF:
```javascript
// Before redirecting to Google
const state = crypto.randomUUID()
sessionStorage.setItem('oauth_state', state)

// On callback
const returnedState = urlParams.get('state')
const savedState = sessionStorage.getItem('oauth_state')
if (returnedState !== savedState) {
  throw new Error('Invalid state - possible CSRF attack')
}
sessionStorage.removeItem('oauth_state')
```

---

## Complete React Example

```jsx
// AuthContext.js
import { createContext, useContext, useState, useEffect } from 'react'

const AuthContext = createContext()

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    checkAuth()
    startTokenRefresh()
    return () => stopTokenRefresh()
  }, [])

  const checkAuth = async () => {
    const accessToken = sessionStorage.getItem('access_token')
    if (!accessToken) {
      setLoading(false)
      return
    }

    try {
      const response = await fetch('http://localhost:8000/auth/me', {
        headers: { 'Authorization': `Bearer ${accessToken}` }
      })
      const userData = await response.json()
      setUser(userData)
    } catch (error) {
      console.error('Auth check failed:', error)
      logout()
    } finally {
      setLoading(false)
    }
  }

  const login = async () => {
    const codeVerifier = generateCodeVerifier()
    const codeChallenge = await generateCodeChallenge(codeVerifier)
    sessionStorage.setItem('pkce_code_verifier', codeVerifier)

    const redirectUri = `${window.location.origin}/auth/callback`
    const response = await fetch(
      `http://localhost:8000/auth/client/google/login?redirect_uri=${redirectUri}&code_challenge=${codeChallenge}`
    )
    const { auth_url } = await response.json()
    window.location.href = auth_url
  }

  const logout = async () => {
    const refreshToken = localStorage.getItem('refresh_token')
    const accessToken = sessionStorage.getItem('access_token')

    if (refreshToken && accessToken) {
      await fetch('http://localhost:8000/auth/logout', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ refresh_token: refreshToken })
      })
    }

    sessionStorage.removeItem('access_token')
    localStorage.removeItem('refresh_token')
    setUser(null)
    window.location.href = '/login'
  }

  return (
    <AuthContext.Provider value={{ user, loading, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
```

---

## Troubleshooting

### CORS Errors

**Symptom:**
```
Access to fetch at 'http://localhost:8000/auth/client/google/login'
from origin 'http://localhost:65263' has been blocked by CORS policy:
No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

**Solution:**

1. **Check backend config.yaml:**
   ```yaml
   authentication:
     cors:
       allowed_origins:
         - "http://localhost:65263"  # Add your client app origin
   ```

2. **Restart backend:**
   ```bash
   uvicorn src.api_server:app --reload
   ```

3. **Verify CORS in logs:**
   ```
   INFO: CORS allowed origins: ['http://localhost:8000', 'http://localhost:65263']
   ```

4. **Test CORS:**
   ```javascript
   // Run in browser console from your client app
   fetch('http://localhost:8000/auth/me')
     .then(r => console.log('CORS OK:', r.status))
     .catch(e => console.error('CORS Error:', e))
   ```

**Common mistakes:**
- ❌ Forgot to add client origin to `allowed_origins`
- ❌ Wrong port number in origin (e.g., `65263` vs `5173`)
- ❌ Missing protocol (must include `http://`)
- ❌ Didn't restart backend after config change

---

### 403 Forbidden on Client App Login

**Symptom:**
```json
{
  "detail": "Client app registration is currently disabled."
}
```

**Solution:**

Enable public signup in `config.yaml`:
```yaml
authentication:
  allow_public_signup: true  # ← Set to true
```

Restart backend and try again.

---

### Getting backstage_admin Instead of client_user

**Symptom:**
- Email is whitelisted in backend config
- Logging in from client app but getting admin role

**Solution:**

Use **client-specific endpoint**, not generic endpoint:

**Wrong:**
```javascript
fetch('/auth/google/login?...')  // Generic endpoint
// Backend auto-detects from redirect_uri (can be spoofed)
```

**Correct:**
```javascript
fetch('/auth/client/google/login?...')  // Client-specific endpoint
// Backend enforces client_user role
```

---

### Token Expired / Invalid Token

**Symptom:**
```json
{
  "detail": "Token expired"
}
```

**Solution:**

1. **Check if access token is old:**
   - Access tokens expire after 15 minutes
   - Implement automatic refresh (see [Token Management](#token-management))

2. **Try refreshing token:**
   ```javascript
   const refreshToken = localStorage.getItem('refresh_token')
   const response = await fetch('/auth/refresh', {
     method: 'POST',
     headers: { 'Content-Type': 'application/json' },
     body: JSON.stringify({ refresh_token: refreshToken })
   })
   const { access_token } = await response.json()
   sessionStorage.setItem('access_token', access_token)
   ```

3. **If refresh fails → re-login:**
   ```javascript
   // Clear tokens and redirect to login
   sessionStorage.removeItem('access_token')
   localStorage.removeItem('refresh_token')
   window.location.href = '/login'
   ```

---

### Google OAuth Error: redirect_uri_mismatch

**Symptom:**
```
Error 400: redirect_uri_mismatch
```

**Solution:**

1. **Go to Google Cloud Console:**
   - APIs & Services → Credentials → OAuth 2.0 Client ID

2. **Add your callback URL to "Authorized redirect URIs":**
   ```
   http://localhost:65263/auth/callback
   ```

3. **Wait 1-2 minutes** for Google to propagate changes

4. **Try login again**

---

### Network Error / Connection Refused

**Symptom:**
```
TypeError: Failed to fetch
net::ERR_CONNECTION_REFUSED
```

**Solution:**

1. **Check if backend is running:**
   ```bash
   curl http://localhost:8000/docs
   # Should return Swagger UI
   ```

2. **Start backend if not running:**
   ```bash
   uvicorn src.api_server:app --reload --host 0.0.0.0 --port 8000
   ```

3. **Check firewall:**
   - Make sure port 8000 is not blocked
   - Check if localhost is accessible

---

## Support

For issues or questions:
- **Backend API**: Check logs at `uvicorn src.api_server:app --reload`
- **GitHub Issues**: https://github.com/yourusername/pocket-guide/issues
- **Email**: support@yourapp.com

---

## Changelog

- **v1.0.0** (2025-01-XX): Initial OAuth 2.0 implementation with PKCE
