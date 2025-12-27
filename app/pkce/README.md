# PKCE (Public) Clients Module

This module manages public OAuth 2.0 clients using the Authorization Code + PKCE flow for web applications, SPAs, and mobile apps.

## 📋 Overview

PKCE clients are used for:
- Single Page Applications (React, Angular, Vue)
- Mobile applications (iOS, Android)
- Web applications (frontend)
- Broker clients (realm federation)

**Key Features:**
- ✅ Public clients (no client secret)
- ✅ Authorization Code + PKCE flow (S256)
- ✅ Multi-Factor Authentication (MFA) support
- ✅ Custom protocol mappers
- ✅ CORS configuration
- ✅ UUID-based client IDs for security

## 🚀 Quick Start

### 1. Deploy MFA Flow (Optional)

```bash
cd ../../config/Authentication/flow/MFA
terraform init
terraform apply -auto-approve
```

### 2. Deploy PKCE Client

```bash
cd ../../../../app/pkce
terraform init
terraform apply -auto-approve
```

### 3. Get Client Configuration

```bash
# View all clients
terraform output pkce_clients

# Get specific client UUID
terraform output -json pkce_clients | jq -r '.["my-app"].client_id'

# Get full client config
terraform output -json pkce_clients | jq '.["my-app"]'
```

## ⚙️ Configuration

### File: `apps.yaml`

```yaml
realm: idp-customer

clients:
  - client_id: my-spa-app
    name: "My SPA Application"
    description: Single page application with PKCE
    enabled: true

    # PKCE Configuration
    pkce:
      challenge_method: S256  # SHA-256 (recommended)

    # Redirect URIs (required)
    redirect_uris:
      - http://localhost:5173/callback
      - https://myapp.com/callback

    # Web origins for CORS (required for SPAs)
    web_origins:
      - http://localhost:5173
      - https://myapp.com

    # Token settings (in seconds)
    token_settings:
      access_token_lifespan: 300      # 5 minutes
      session_idle_timeout: 1800      # 30 minutes
      session_max_lifespan: 36000     # 10 hours

    # Consent screen
    consent_required: false

    # Authentication Flow (optional - requires MFA flow deployed)
    authentication_flow:
      browser_flow: mfa-browser  # Custom MFA flow

    # Protocol Mappers
    mappers:
      - type: user_attribute
        name: email
        user_attribute: email
        claim_name: email

      - type: user_attribute
        name: firstName
        user_attribute: firstName
        claim_name: given_name

      - type: user_attribute
        name: lastName
        user_attribute: lastName
        claim_name: family_name

      - type: user_attribute
        name: username
        user_attribute: username
        claim_name: preferred_username

      - type: audience
        name: audience
        audience: self  # Uses client's own UUID
```

## 🔐 PKCE Flow

### What is PKCE?

**PKCE** (Proof Key for Code Exchange) protects against authorization code interception attacks by using a cryptographic challenge.

### Flow Steps

```
1. App generates code_verifier (random 43-128 char string)
2. App creates code_challenge = SHA256(code_verifier)
3. App redirects to authorization endpoint with code_challenge
4. User authenticates (+ MFA if configured)
5. Keycloak stores code_challenge and returns authorization code
6. App exchanges code + code_verifier for tokens
7. Keycloak verifies SHA256(code_verifier) == code_challenge
8. Keycloak issues access token and ID token
```

### Example Implementation (JavaScript)

```javascript
// 1. Generate code verifier
function generateCodeVerifier() {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return base64URLEncode(array);
}

// 2. Generate code challenge
async function generateCodeChallenge(verifier) {
  const encoder = new TextEncoder();
  const data = encoder.encode(verifier);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return base64URLEncode(new Uint8Array(hash));
}

// 3. Authorization request
const codeVerifier = generateCodeVerifier();
const codeChallenge = await generateCodeChallenge(codeVerifier);

// Store code verifier for later
sessionStorage.setItem('code_verifier', codeVerifier);

const authUrl = `${AUTH_ENDPOINT}?` +
  `client_id=${CLIENT_ID}&` +
  `redirect_uri=${REDIRECT_URI}&` +
  `response_type=code&` +
  `scope=openid profile email&` +
  `code_challenge=${codeChallenge}&` +
  `code_challenge_method=S256`;

window.location.href = authUrl;

// 4. Token exchange (in callback)
const codeVerifier = sessionStorage.getItem('code_verifier');
const code = new URLParams(window.location.search).get('code');

const tokenResponse = await fetch(TOKEN_ENDPOINT, {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    grant_type: 'authorization_code',
    code: code,
    redirect_uri: REDIRECT_URI,
    client_id: CLIENT_ID,
    code_verifier: codeVerifier
  })
});

const tokens = await tokenResponse.json();
// tokens.access_token, tokens.id_token, tokens.refresh_token
```

## 🔒 Multi-Factor Authentication (MFA)

### Enable MFA

1. **Deploy MFA flow** (see Quick Start)
2. **Configure client** to use MFA:

```yaml
authentication_flow:
  browser_flow: mfa-browser  # Custom MFA flow with WebAuthn
```

### MFA Flow Components

- **First Factor**: Username/Password
- **Second Factor**: WebAuthn (fingerprint, Face ID, security keys, Windows Hello)

### User Setup

Users must register WebAuthn credentials:
1. Login to Keycloak Account Console
2. Navigate to **Security** → **Signing In**
3. Click **Set up Security Key** or **Passwordless**
4. Follow browser prompts to register device

## 📝 Protocol Mappers

### User Attribute Mapper

Maps user attributes to JWT claims:

```yaml
- type: user_attribute
  name: email
  user_attribute: email      # Source attribute
  claim_name: email          # Target claim in JWT
```

### Audience Mapper

Adds `aud` claim to tokens:

```yaml
- type: audience
  name: audience
  audience: self  # Use "self" for client's own UUID
  # OR
  audience: custom-audience-value
```

**Resulting JWT:**
```json
{
  "aud": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

## 🌐 CORS Configuration

### Web Origins

Add allowed origins for CORS:

```yaml
web_origins:
  - http://localhost:5173      # Development
  - https://myapp.com          # Production
  - http://localhost:8080      # Keycloak admin
```

### Custom CORS Headers

Pre-configured custom headers:
- Standard: `Accept`, `Authorization`, `Content-Type`
- Custom: `ngrok-skip-browser-warning` (for ngrok development)

## 🔍 Viewing Outputs

### All PKCE Clients

```bash
terraform output pkce_clients
```

### Specific Client

```bash
terraform output -json pkce_clients | jq '.["my-app"]'
```

Output:
```json
{
  "client_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "client_name": "My SPA Application",
  "client_type": "PUBLIC",
  "flow_type": "Authorization Code + PKCE",
  "internal_id": "keycloak-internal-id",
  "resource_uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "scope_id": "scope-id",
  "redirect_uris": ["http://localhost:5173/callback"],
  "web_origins": ["http://localhost:5173"],
  "authorization_url": "https://keycloak/realms/realm/protocol/openid-connect/auth",
  "token_url": "https://keycloak/realms/realm/protocol/openid-connect/token",
  "userinfo_url": "https://keycloak/realms/realm/protocol/openid-connect/userinfo",
  "logout_url": "https://keycloak/realms/realm/protocol/openid-connect/logout",
  "pkce_method": "S256",
  "scopes": ["openid", "profile", "email"]
}
```

### Client UUID Only

```bash
terraform output -json pkce_clients | jq -r '.["my-app"].client_id'
```

### OIDC Endpoints

```bash
terraform output -json pkce_clients | jq -r '.["my-app"] | {authorization_url, token_url, userinfo_url, logout_url}'
```

## 📝 Adding New PKCE Clients

### 1. Edit `apps.yaml`

```yaml
clients:
  - client_id: my-new-app
    name: "My New Application"
    enabled: true
    pkce:
      challenge_method: S256
    redirect_uris:
      - http://localhost:4200/callback
    web_origins:
      - http://localhost:4200
    token_settings:
      access_token_lifespan: 300
      session_idle_timeout: 1800
      session_max_lifespan: 36000
    consent_required: false
    mappers:
      - type: audience
        name: audience
        audience: self
```

### 2. Apply Changes

```bash
terraform apply
```

### 3. Get Client UUID

```bash
terraform output -json pkce_clients | jq -r '.["my-new-app"].client_id'
```

## 🛠️ Troubleshooting

### "Invalid redirect_uri"

**Problem**: Redirect URI not allowed

**Solution**: Add the URI to `redirect_uris` in `apps.yaml`:
```yaml
redirect_uris:
  - http://localhost:5173/callback
  - https://myapp.com/callback
```

### "Missing code_challenge_method"

**Problem**: PKCE not configured

**Solution**: Ensure PKCE is enabled in `apps.yaml`:
```yaml
pkce:
  challenge_method: S256
```

### "Invalid client"

**Problem**: Client UUID mismatch

**Solution**:
1. Get correct UUID: `terraform output -json pkce_clients | jq -r '.["my-app"].client_id'`
2. Update your app configuration with the correct UUID

### CORS Errors

**Problem**: `Access-Control-Allow-Origin` error

**Solution**: Add frontend URL to `web_origins`:
```yaml
web_origins:
  - http://localhost:5173  # Your frontend URL
  - https://myapp.com
```

### MFA Not Triggering

**Problem**: Users don't see WebAuthn prompt

**Solution**:
1. Verify `mfa-browser` flow exists: `cd ../../../config/Authentication/flow/MFA && terraform apply`
2. Ensure client has `authentication_flow.browser_flow: mfa-browser`
3. Check users have registered WebAuthn credentials

### "Output 'clients' not found"

**Problem**: Wrong output name

**Solution**: Use `pkce_clients` not `clients`:
```bash
terraform output pkce_clients  # Correct
```

## 🔒 Security Best Practices

### 1. PKCE
- ✅ Always use `S256` (SHA-256) challenge method
- ✅ Generate cryptographically random code verifiers (43-128 chars)
- ❌ Never use `plain` challenge method

### 2. Token Lifespans
- **Access Token**: 5-15 minutes (short-lived)
- **Session Idle**: 30 minutes (user inactivity timeout)
- **Session Max**: 10 hours (absolute maximum)

### 3. Redirect URIs
- ✅ Use exact matches (no wildcards)
- ✅ Use HTTPS in production
- ✅ Limit to necessary URIs only

### 4. Web Origins
- ✅ Specify exact origins for CORS
- ✅ Don't use wildcards (`*`)
- ✅ Use HTTPS in production

### 5. MFA
- ✅ Enable MFA for sensitive applications
- ✅ Require WebAuthn for additional security
- ✅ Educate users on registering devices

## 📊 Terraform Resources

This module creates:

- `keycloak_openid_client.pkce` - PKCE client
- `random_uuid.client` - Client UUID
- `keycloak_openid_client_scope.pkce_scope` - Custom scope per client
- `keycloak_openid_user_attribute_protocol_mapper.user_attributes` - User attribute mappers
- `keycloak_openid_audience_protocol_mapper.audience` - Audience mappers

## 🔗 Related

- **M2M Clients**: See `../m2m/` for confidential clients
- **Scopes**: See `../scopes/` for custom scopes
- **MFA Flow**: See `../../config/Authentication/flow/MFA/` for MFA setup
- **Main README**: See `../README.md` for complete overview
