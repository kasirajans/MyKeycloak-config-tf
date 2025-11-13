# Keycloak SSO Applications Configuration

This folder manages SSO application clients in Keycloak with two flow types:
1. **PKCE Client** - Authorization Code + PKCE for web/mobile applications
2. **M2M Client** - Client Credentials flow for machine-to-machine communication

## Client Types

### 1. PKCE Client (Public)
- **Flow**: Authorization Code + PKCE
- **Use Case**: Web apps, SPAs, mobile apps
- **Authentication**: No client secret (public client)
- **Security**: Uses PKCE (Proof Key for Code Exchange) to prevent authorization code interception

### 2. M2M Client (Confidential)
- **Flow**: Client Credentials (OAuth 2.0)
- **Use Case**: Service-to-service communication, backend APIs
- **Authentication**: Client ID + Client Secret
- **Security**: Confidential client with service account

## Setup

1. **Configure clients in `terraform.tfvars`:**
   - Update `pkce_client_id` and `m2m_client_id`
   - Set redirect URIs for PKCE client
   - Generate a strong secret for M2M client
   - Choose the target realm (consumer or master)

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Review the plan:**
   ```bash
   terraform plan
   ```

4. **Apply configuration:**
   ```bash
   terraform apply
   ```

## PKCE Client Usage

### Authorization Request
```
GET /realms/{realm}/protocol/openid-connect/auth
  ?client_id=webapp-pkce
  &redirect_uri=http://localhost:3000/callback
  &response_type=code
  &scope=openid profile email
  &code_challenge={code_challenge}
  &code_challenge_method=S256
```

### Token Exchange
```bash
POST /realms/{realm}/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&client_id=webapp-pkce
&code={authorization_code}
&redirect_uri=http://localhost:3000/callback
&code_verifier={code_verifier}
```

## M2M Client Usage

### Get Access Token
```bash
curl -X POST http://localhost:8080/realms/consumer/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=backend-service-m2m" \
  -d "client_secret=your-secure-client-secret-here-change-me" \
  -d "grant_type=client_credentials"
```

### Response
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 3600,
  "token_type": "Bearer",
  "scope": "email profile"
}
```

## Security Best Practices

1. **PKCE Client:**
   - Always use PKCE (S256 method)
   - Validate redirect URIs strictly
   - Keep access token lifespan short (5-15 minutes)
   - Use refresh tokens for long sessions

2. **M2M Client:**
   - Generate strong client secrets (min 32 characters)
   - Rotate secrets regularly
   - Store secrets in secure vaults (not in code)
   - Limit service account permissions
   - Monitor token usage

3. **General:**
   - Use HTTPS in production
   - Enable CORS properly for web origins
   - Implement token validation in your apps
   - Set appropriate token lifespans

## Outputs

After applying, get client details:
```bash
terraform output
terraform output -json
terraform output m2m_client_secret  # View M2M secret
```

## Configuration Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `pkce_client_id` | Client ID for PKCE app | `webapp-pkce` |
| `pkce_redirect_uris` | Valid redirect URIs | `["http://localhost:3000/callback"]` |
| `m2m_client_id` | Client ID for M2M service | `backend-service-m2m` |
| `m2m_client_secret` | Secret for M2M client | `secure-secret-32-chars-min` |
| `keycloak_realm` | Target realm | `consumer` or `master` |

## Testing

### Test PKCE Flow
Use OAuth 2.0 Playground or implement in your web app with a library like:
- JavaScript: `keycloak-js`, `oidc-client-ts`
- React: `@react-keycloak/web`
- Angular: `keycloak-angular`

### Test M2M Flow
```bash
# Get token
TOKEN=$(curl -s -X POST http://localhost:8080/realms/consumer/protocol/openid-connect/token \
  -d "client_id=backend-service-m2m" \
  -d "client_secret=your-secret" \
  -d "grant_type=client_credentials" | jq -r .access_token)

# Use token to call protected API
curl -H "Authorization: Bearer $TOKEN" https://your-api.com/protected
```

## Troubleshooting

- **Invalid redirect URI**: Add the exact URI to `pkce_redirect_uris`
- **CORS errors**: Add origin to `pkce_web_origins`
- **M2M unauthorized**: Check client secret and ensure service_accounts_enabled is true
- **Token expired**: Adjust token lifespan variables
