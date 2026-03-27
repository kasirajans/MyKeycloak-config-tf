# Token Exchange Testing Guide

This guide explains how to test the OAuth 2.0 Token Exchange (RFC 8693) flow for `AgentResource` clients in Keycloak with Okta federation.

## Overview

Token exchange allows clients to:
- Exchange an Okta IdToken for a Keycloak access token
- Implement federated identity flows
- Enable cross-realm/cross-provider authentication

**Endpoint:**
```
POST /realms/{realm}/protocol/openid-connect/token
```

## Setup

### 1. Deploy AgentResource Client

First, create an `AgentResource` client in your `apps.yaml`:

```yaml
clients:
  - app_name: mcpServer
    service_type: AgentResource
    owner: Kraaj
    team: Identity Platform
    email: identity-platform@company.com
    scope: pd:user:read
    enabled: true
```

Then apply terraform:
```bash
terraform apply
```

Terraform will output the client credentials. Save them.

### 2. Update .env

Add these to your `.env` file:

```bash
# Token Exchange Client Credentials (AgentResource)
TOKEN_EXCHANGE_CLIENT_ID=<client_id_from_terraform>
TOKEN_EXCHANGE_CLIENT_SECRET=<client_secret_from_terraform>

# Okta IdToken (get from Okta)
OKTA_ID_TOKEN=<okta_id_token>

# Token Exchange Parameters (defaults shown)
SUBJECT_TOKEN_TYPE=urn:ietf:params:oauth:token-type:id_token
REQUESTED_TOKEN_TYPE=urn:ietf:params:oauth:token-type:access_token
AUDIENCE=resource-a-server
```

### 3. Obtain Okta IdToken

**Option A: From existing Okta session**
```bash
# 1. Get authorization code
curl -X GET "https://your-okta-domain/oauth2/v1/authorize" \
  -d "client_id=YOUR_OKTA_CLIENT_ID" \
  -d "redirect_uri=http://localhost:8080/callback" \
  -d "response_type=code" \
  -d "scope=openid profile email"

# 2. Exchange for tokens
curl -X POST "https://your-okta-domain/oauth2/v1/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=YOUR_OKTA_CLIENT_ID" \
  -d "client_secret=YOUR_OKTA_CLIENT_SECRET" \
  -d "code=<auth_code>" \
  -d "redirect_uri=http://localhost:8080/callback"

# 3. Extract id_token from response and set in .env
```

**Option B: For testing/development**
Use a mock IdToken (will be validated by Keycloak):
```bash
# Keycloak will validate the token signature against configured Okta broker
# If validation fails, check that Okta OIDC broker is properly configured in Keycloak
```

## Test Scripts

### Bash Script: test-token-exchange.sh

**Usage:**
```bash
chmod +x test-token-exchange.sh
./test-token-exchange.sh
```

**Features:**
- Loads credentials from `.env`
- Sends token exchange request with all RFC 8693 parameters
- Validates HTTP response
- Decodes JWT payload (if `jq` installed)
- Shows full token claims

**Example output:**
```
Testing token exchange endpoint (RFC 8693)...
Keycloak URL: http://localhost:8080
Realm: AIAgent
...

HTTP Status: 200

Response:
{
  "access_token": "eyJhbGc...",
  "token_type": "Bearer",
  "expires_in": 1800,
  "scope": "pd:user:read"
}

Access Token (decoded):
{
  "permissions": ["user:read"],
  "exchange_context": "okta_federation",
  "resource_access": {...}
}
```

### REST Client: token-exchange.http

**Requirements:**
- VS Code REST Client extension

**Usage:**
1. Open `token-exchange.http` in VS Code
2. Update variables at the top
3. Click "Send Request" on each request

**Available requests:**
- `tokenExchange` - Exchange Okta IdToken for access token
- `verifyToken` - Introspect the exchanged token
- `verifyTokenOnline` - Decode on jwt.io

### cURL Command

```bash
curl -X POST "http://localhost:8080/realms/AIAgent/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" \
  -d "client_id=aiagent_AgentResource_mcpServer" \
  -d "client_secret=<secret>" \
  -d "subject_token=<okta_id_token>" \
  -d "subject_token_type=urn:ietf:params:oauth:token-type:id_token" \
  -d "requested_token_type=urn:ietf:params:oauth:token-type:access_token" \
  -d "audience=resource-a-server" \
  -d "scope=pd:user:read"
```

## Token Exchange Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `grant_type` | `urn:ietf:params:oauth:grant-type:token-exchange` | RFC 8693 token exchange grant |
| `client_id` | Client ID | AgentResource client ID (e.g., `aiagent_AgentResource_mcpServer`) |
| `client_secret` | Secret | AgentResource client secret |
| `subject_token` | Okta IdToken | The token being exchanged |
| `subject_token_type` | `urn:ietf:params:oauth:token-type:id_token` | IdToken type (RFC 8693) |
| `requested_token_type` | `urn:ietf:params:oauth:token-type:access_token` | Requested token type |
| `audience` | String | Target resource server (e.g., `resource-a-server`) |
| `scope` | String | Requested scope (e.g., `pd:user:read`) |

## Response Format

**Success (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 1800,
  "scope": "pd:user:read"
}
```

**Error (400/401/403):**
```json
{
  "error": "invalid_grant",
  "error_description": "Token exchange failed: subject token validation error"
}
```

## Troubleshooting

### "Token exchange failed: subject token validation error"
- **Cause**: Okta IdToken signature invalid or Okta broker not configured
- **Fix**:
  1. Verify OKTA_ID_TOKEN is a valid JWT
  2. Ensure Okta OIDC broker is configured in AIAgent realm
  3. Check broker certificate/key configuration

### "Subject token type not supported"
- **Cause**: Using wrong `subject_token_type`
- **Fix**: Use `urn:ietf:params:oauth:token-type:id_token` or `urn:ietf:params:oauth:token-type:access_token`

### "Client not found"
- **Cause**: Wrong client ID or client not created
- **Fix**: 
  1. Check client ID matches Terraform output
  2. Run `terraform apply` to create the AgentResource client
  3. Verify client exists in Keycloak console

### "Requested scope not available"
- **Cause**: Scope not assigned to client
- **Fix**:
  1. Ensure `pd:user:read` scope exists in scopes module
  2. Verify `apps.yaml` has `scope: pd:user:read`
  3. Run `terraform apply` to assign scope

## Additional Resources

- [RFC 8693 - OAuth 2.0 Token Exchange](https://tools.ietf.org/html/rfc8693)
- [Keycloak Token Exchange Documentation](https://www.keycloak.org/docs/latest/server_admin/#_token_exchange)
- [Okta OAuth 2.0 Documentation](https://developer.okta.com/docs/reference/api/oidc/)
