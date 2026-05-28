# Backend: Sign in with Apple — Implementation Spec

## What the mobile app sends

`POST /auth/client/apple/verify-token`

```json
{
  "identity_token": "<JWT string from Apple>",
  "authorization_code": "<one-time code string from Apple>"
}
```

- `identity_token` — a signed JWT issued by Apple. Contains the user's Apple ID, email, and expiry.
- `authorization_code` — a short-lived one-time code. Used to call Apple's token endpoint to get a `refresh_token` (only works **once**, on first sign-in).

## What the endpoint must return

Same shape as the existing Google verify-token response:

```json
{
  "access_token": "<your app JWT>",
  "refresh_token": "<your app refresh token>",
  "token_type": "bearer",
  "expires_in": 3600
}
```

Return `401` on any verification failure.

---

## Step-by-step implementation

### Step 1 — Verify the identity_token JWT

Apple signs the identity token with RSA keys published at:

```
GET https://appleid.apple.com/auth/keys
```

This returns a JWKS (JSON Web Key Set). You must:

1. Decode the JWT header to get the `kid` (key ID).
2. Fetch the matching public key from the JWKS endpoint.
3. Verify the JWT signature using that key.
4. Validate these claims:

| Claim | Expected value |
|-------|---------------|
| `iss` | `https://appleid.apple.com` |
| `aud` | `com.pocketguide.pocketGuideMobile` |
| `exp` | must be in the future |

**Python example (using `PyJWT` + `cryptography`):**

```python
import jwt
import requests
from jwt.algorithms import RSAAlgorithm

APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"
BUNDLE_ID = "com.pocketguide.pocketGuideMobile"

def verify_apple_identity_token(identity_token: str) -> dict:
    # 1. Get Apple's public keys
    jwks = requests.get(APPLE_KEYS_URL).json()

    # 2. Decode header to find the right key
    header = jwt.get_unverified_header(identity_token)
    matching_key = next(k for k in jwks["keys"] if k["kid"] == header["kid"])
    public_key = RSAAlgorithm.from_jwk(matching_key)

    # 3. Verify and decode
    claims = jwt.decode(
        identity_token,
        public_key,
        algorithms=["RS256"],
        audience=BUNDLE_ID,
        issuer="https://appleid.apple.com",
    )
    return claims
    # claims["sub"]   → Apple user ID (stable, use as primary key)
    # claims["email"] → user's email (may be a relay address)
    # claims["email_verified"] → bool
```

Cache the JWKS response for ~1 hour to avoid hitting Apple's endpoint on every request.

---

### Step 2 — Extract user identity

From the verified claims:

```python
apple_user_id = claims["sub"]          # stable unique ID — store this
email         = claims.get("email")    # may be None after first sign-in
```

> **Important:** Apple only sends `email` in the identity token on the **first sign-in**. After that, the email field may be absent. Always store the email from the first sign-in against the `apple_user_id`.

---

### Step 3 — First sign-in only: exchange authorization_code

On first sign-in, call Apple's token endpoint to confirm the code is valid and to obtain an Apple `refresh_token` (so you can optionally revoke access later):

```
POST https://appleid.apple.com/auth/token
Content-Type: application/x-www-form-urlencoded

client_id=com.pocketguide.pocketGuideMobile
&client_secret=<generated JWT — see below>
&code=<authorization_code from request>
&grant_type=authorization_code
```

**Generating `client_secret`** — Apple requires a JWT signed with an ES256 private key:

```python
import jwt, time

def make_apple_client_secret(
    team_id: str,       # e.g. "U8JSCA354Q"
    client_id: str,     # bundle ID
    key_id: str,        # from Apple Developer portal
    private_key: str,   # .p8 file contents
) -> str:
    now = int(time.time())
    return jwt.encode(
        {
            "iss": team_id,
            "iat": now,
            "exp": now + 3600,        # max 6 months
            "aud": "https://appleid.apple.com",
            "sub": client_id,
        },
        private_key,
        algorithm="ES256",
        headers={"kid": key_id},
    )
```

You'll need three values from Apple Developer Portal (see Apple Developer Portal setup guide):
- `APPLE_TEAM_ID` = `U8JSCA354Q`
- `APPLE_KEY_ID` = from the key you create
- `APPLE_PRIVATE_KEY` = contents of the `.p8` file you download

Store these as environment variables. **The `.p8` file can only be downloaded once.**

---

### Step 4 — Find or create user

```python
user = db.query(User).filter_by(apple_id=apple_user_id).first()

if not user:
    # First sign-in — create account
    user = User(
        apple_id=apple_user_id,
        email=email,           # store now; may not come again
        auth_provider="apple",
    )
    db.add(user)
    db.commit()
```

If a user with the same email already exists from Google Sign-In, decide whether to link the accounts or block the sign-in — your choice of policy.

---

### Step 5 — Issue your app tokens

Same as Google sign-in — generate your own JWT access token and refresh token:

```python
access_token  = create_access_token(subject=str(user.id))
refresh_token = create_refresh_token(subject=str(user.id))

return {
    "access_token":  access_token,
    "refresh_token": refresh_token,
    "token_type":    "bearer",
    "expires_in":    3600,
}
```

---

## Environment variables needed

```
APPLE_TEAM_ID=U8JSCA354Q
APPLE_KEY_ID=<10-char key ID from portal>
APPLE_PRIVATE_KEY=<contents of .p8 file, with newlines>
APPLE_BUNDLE_ID=com.pocketguide.pocketGuideMobile
```

---

## Error handling

| Situation | HTTP response |
|-----------|--------------|
| JWT signature invalid | `401 Invalid identity token` |
| `aud` mismatch | `401 Invalid audience` |
| Token expired | `401 Token expired` |
| `authorization_code` exchange fails | Log it, but **don't fail the login** — the identity token verification is sufficient |
| Apple JWKS fetch fails | `503 Unable to verify token` |

---

## Summary checklist

- [ ] `POST /auth/client/apple/verify-token` route created
- [ ] Apple JWKS fetched and cached to verify JWT signature
- [ ] Claims validated (`iss`, `aud`, `exp`)
- [ ] `apple_id` column on User model
- [ ] `client_secret` JWT generation with `.p8` key
- [ ] `authorization_code` exchanged on first sign-in
- [ ] User find-or-create logic
- [ ] Access + refresh tokens returned in standard shape
- [ ] `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` in env
