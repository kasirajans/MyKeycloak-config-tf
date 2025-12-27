# Password Grant Clients Module

This module manages OAuth 2.0 clients using the Resource Owner Password Credentials grant.

## ⚠️ Security Warning

**The Password Grant flow is deprecated and considered insecure.** It should only be used for:
- Legacy applications that cannot be migrated
- Testing and development environments
- Internal tools where other flows are not feasible

**For new applications, use:**
- **PKCE flow** (`../pkce/`) for web/mobile apps
- **Client Credentials flow** (`../m2m/`) for service-to-service

## 📋 Overview

Password Grant allows applications to exchange username/password directly for access tokens.

**Security Risks:**
- ❌ Application handles user credentials directly
- ❌ No protection against credential theft
- ❌ Cannot support MFA easily
- ❌ Violates OAuth 2.0 best practices

## 🚀 Quick Start

### Deploy Password Grant Client

```bash
cd password-grant
terraform init
terraform apply -auto-approve
```

### Get Client Configuration

```bash
terraform output password_grant_clients
```

## ⚙️ Configuration

### File: `apps.yaml`

```yaml
realm: my-realm

clients:
  - client_id: legacy-app
    name: "Legacy Application"
    description: Legacy app using password grant
    enabled: true

    # Access type (PUBLIC or CONFIDENTIAL)
    access_type: CONFIDENTIAL  # Use CONFIDENTIAL if client can keep secret

    # Token settings (in seconds)
    token_settings:
      access_token_lifespan: 300  # 5 minutes (keep short)
```

## 🔑 Getting Access Tokens

### For Confidential Clients (with secret)

```bash
curl -X POST "https://keycloak/realms/my-realm/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=<client-uuid>" \
  -d "client_secret=<client-secret>" \
  -d "username=user@example.com" \
  -d "password=userpassword" \
  -d "scope=openid profile email"
```

### For Public Clients (no secret)

```bash
curl -X POST "https://keycloak/realms/my-realm/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=<client-uuid>" \
  -d "username=user@example.com" \
  -d "password=userpassword" \
  -d "scope=openid profile email"
```

### Response

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 300,
  "refresh_expires_in": 1800,
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "scope": "openid profile email"
}
```

## 🔍 Viewing Outputs

```bash
# All password grant clients
terraform output password_grant_clients

# Specific client
terraform output -json password_grant_clients | jq '.["legacy-app"]'

# Client UUID
terraform output -json password_grant_clients | jq -r '.["legacy-app"].client_id'

# Client secret (if confidential)
terraform output -json password_grant_client_secrets | jq -r '.["legacy-app"]'
```

## 🔒 Migration Recommendations

### Migrate to PKCE Flow

**For web/mobile apps**, migrate to Authorization Code + PKCE:

**Before (Password Grant):**
```javascript
// ❌ Insecure - app handles credentials
const response = await fetch(TOKEN_URL, {
  method: 'POST',
  body: new URLSearchParams({
    grant_type: 'password',
    client_id: CLIENT_ID,
    username: username,
    password: password
  })
});
```

**After (PKCE):**
```javascript
// ✅ Secure - credentials never touch app
const codeVerifier = generateCodeVerifier();
const codeChallenge = await generateCodeChallenge(codeVerifier);

// Redirect to Keycloak login
window.location.href = `${AUTH_URL}?` +
  `client_id=${CLIENT_ID}&` +
  `redirect_uri=${REDIRECT_URI}&` +
  `response_type=code&` +
  `code_challenge=${codeChallenge}&` +
  `code_challenge_method=S256`;

// Exchange code for tokens (in callback)
const response = await fetch(TOKEN_URL, {
  method: 'POST',
  body: new URLSearchParams({
    grant_type: 'authorization_code',
    code: authorizationCode,
    redirect_uri: REDIRECT_URI,
    client_id: CLIENT_ID,
    code_verifier: codeVerifier
  })
});
```

See `../pkce/README.md` for complete PKCE implementation.

### Migrate to Client Credentials Flow

**For service-to-service**, migrate to Client Credentials:

**Before (Password Grant with service account):**
```bash
# ❌ Using user credentials for service
curl -d "grant_type=password" \
     -d "client_id=$CLIENT_ID" \
     -d "username=service-user" \
     -d "password=service-password"
```

**After (Client Credentials):**
```bash
# ✅ Using client credentials
curl -d "grant_type=client_credentials" \
     -d "client_id=$CLIENT_ID" \
     -d "client_secret=$CLIENT_SECRET"
```

See `../m2m/README.md` for complete M2M implementation.

## 🛠️ Troubleshooting

### "Invalid grant"

**Problem**: Username/password incorrect

**Solution**:
1. Verify user exists in realm
2. Check password is correct
3. Ensure user is enabled
4. Check user's email is verified (if required)

### "Client not enabled for password grant"

**Problem**: Direct access grants not enabled

**Solution**: Verify Terraform configuration enables password grant:
```hcl
direct_access_grants_enabled = true
```

### "Unauthorized client"

**Problem**: Client secret incorrect (for confidential clients)

**Solution**:
1. Get secret: `terraform output -json password_grant_client_secrets`
2. Verify secret in token request

## 📊 Comparison Table

| Feature | Password Grant | PKCE | Client Credentials |
|---------|---------------|------|-------------------|
| **Use Case** | Legacy apps | Web/Mobile apps | Service-to-service |
| **Security** | ❌ Low | ✅ High | ✅ High |
| **OAuth 2.0 Status** | ⚠️ Deprecated | ✅ Recommended | ✅ Recommended |
| **Client Secret** | Optional | ❌ No | ✅ Yes |
| **User Credentials** | ✅ App handles | ❌ Never exposed | ❌ N/A |
| **MFA Support** | ❌ Difficult | ✅ Built-in | ❌ N/A |
| **Refresh Tokens** | ✅ Yes | ✅ Yes | ❌ No |

## 🔗 Related

- **PKCE Clients**: See `../pkce/` for secure web/mobile auth
- **M2M Clients**: See `../m2m/` for service-to-service auth
- **Main README**: See `../README.md` for complete overview
