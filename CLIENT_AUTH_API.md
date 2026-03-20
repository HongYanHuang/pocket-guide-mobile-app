# Client-Side Authentication API Guide

This guide explains how to integrate Google OAuth 2.0 authentication into your client-side application (web or mobile) using the Pocket Guide API.

## Table of Contents
- [Overview](#overview)
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

## Authentication Flow

```
┌─────────────┐
│ Your App    │
│ (Client)    │
└──────┬──────┘
       │
       │ 1. Generate PKCE challenge
       │ 2. GET /auth/google/login
       │
       v
┌─────────────────┐
│ Backend API     │
└────────┬────────┘
         │
         │ 3. Returns Google OAuth URL
         │
         v
┌─────────────────┐
│ Google OAuth    │
│ (User consents) │
└────────┬────────┘
         │
         │ 4. Redirects to your callback URL
         │    with authorization code
         │
         v
┌─────────────┐
│ Your App    │
│ (Callback)  │
└──────┬──────┘
       │
       │ 5. GET /auth/google/callback
       │    with code + PKCE verifier
       │
       v
┌─────────────────┐
│ Backend API     │
│ Returns tokens  │
└─────────────────┘
       │
       │ access_token (JWT, 15 min)
       │ refresh_token (UUID, 7 days)
       │
       v
┌─────────────┐
│ Your App    │
│ (Authenticated)
└─────────────┘
```

---

## API Endpoints

### 1. Initiate Login

**GET** `/auth/google/login`

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `redirect_uri` | string | Yes | Your app's callback URL (must match Google Console) |
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
curl "http://localhost:8000/auth/google/login?redirect_uri=http://localhost:3000/auth/callback&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
```

---

### 2. Exchange Code for Tokens

**GET** `/auth/google/callback`

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

  // 3. Get Google OAuth URL
  const redirectUri = `${window.location.origin}/auth/callback`
  const response = await fetch(
    `http://localhost:8000/auth/google/login?redirect_uri=${redirectUri}&code_challenge=${codeChallenge}`
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

  // 3. Exchange code for tokens
  const response = await fetch(
    `http://localhost:8000/auth/google/callback?code=${code}&state=${state}&code_verifier=${codeVerifier}`
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

### 1. Always Use PKCE
Never skip PKCE code challenge/verifier - it prevents authorization code interception.

### 2. Validate Redirect URIs
Ensure your callback URL is registered in Google Cloud Console:
```
Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Client ID
→ Authorized redirect URIs
```

### 3. Token Storage
- **Never** store tokens in cookies without `HttpOnly` flag
- **Never** expose tokens in URLs
- **Always** use `sessionStorage` for access tokens
- Use `localStorage` only for refresh tokens (if you need persistence)

### 4. HTTPS Only (Production)
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
      `http://localhost:8000/auth/google/login?redirect_uri=${redirectUri}&code_challenge=${codeChallenge}`
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

## Support

For issues or questions:
- **Backend API**: Check logs at `uvicorn src.api_server:app --reload`
- **GitHub Issues**: https://github.com/yourusername/pocket-guide/issues
- **Email**: support@yourapp.com

---

## Changelog

- **v1.0.0** (2025-01-XX): Initial OAuth 2.0 implementation with PKCE
