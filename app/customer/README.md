# Keycloak OAuth Client Management

This directory contains Terraform configurations for managing different types of OAuth clients in Keycloak, organized by OAuth flow type.

## 📁 Directory Structure

```
app/customer/
├── pkce/                    # Authorization Code + PKCE flow clients
│   ├── apps.yaml           # Multiple PKCE client configurations
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── terraform.tfvars
│
├── m2m/                     # Client Credentials (Machine-to-Machine) flow clients
│   ├── apps.yaml           # Multiple M2M client configurations
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── terraform.tfvars
│
└── password-grant/          # Resource Owner Password Credentials flow clients
    ├── apps.yaml           # Multiple Password Grant client configurations
    ├── main.tf
    ├── outputs.tf
    ├── variables.tf
    └── terraform.tfvars
```

## 🔐 OAuth Flow Types

### 1. PKCE (Authorization Code + PKCE)
**Directory:** `pkce/`  
**Use Case:** Web and mobile applications where the user logs in interactively  
**Client Type:** PUBLIC  
**Security:** High - Uses PKCE (Proof Key for Code Exchange) with SHA-256

**Example apps.yaml:**
```yaml
realm: customer

clients:
  - client_id: webapp-pkce
    name: Web Application (PKCE)
    enabled: true
    pkce:
      challenge_method: S256
    redirect_uris:
      - http://localhost:5173/callback
    web_origins:
      - http://localhost:5173
    token_settings:
      access_token_lifespan: 300
      session_idle_timeout: 1800
      session_max_lifespan: 36000
    consent_required: false
```

### 2. M2M (Machine-to-Machine / Client Credentials)
**Directory:** `m2m/`  
**Use Case:** Service-to-service communication without user interaction  
**Client Type:** CONFIDENTIAL  
**Security:** High - Uses client_id and client_secret (48-char random)

**Example apps.yaml:**
```yaml
realm: customer

clients:
  - client_id: backend-service-m2m
    name: Backend Service (M2M)
    enabled: true
    token_settings:
      access_token_lifespan: 3600
    service_account_roles: []
```

### 3. Password Grant (ROPC - Resource Owner Password Credentials)
**Directory:** `password-grant/`  
**Use Case:** Legacy applications that need direct username/password authentication  
**Client Type:** CONFIDENTIAL or PUBLIC  
**Security:** ⚠️ Lower - User credentials are directly exposed to the application  
**Status:** ⚠️ Legacy/Deprecated - Only use for migration scenarios

**Example apps.yaml:**
```yaml
realm: customer

clients:
  - client_id: legacy-app-password
    name: Legacy Application (Password Grant)
    enabled: true
    access_type: CONFIDENTIAL  # or PUBLIC
    token_settings:
      access_token_lifespan: 300
      refresh_token_lifespan: 1800
      session_idle_timeout: 1800
      session_max_lifespan: 36000
    consent_required: false
```

## 🚀 Usage

### Deploy PKCE Clients
```bash
cd pkce/
terraform init
terraform plan
terraform apply

# View client configurations
terraform output pkce_clients
```

### Deploy M2M Clients
```bash
cd m2m/
terraform init
terraform plan
terraform apply

# View client configurations and secrets
terraform output m2m_clients
terraform output m2m_client_secrets
```

### Deploy Password Grant Clients
```bash
cd password-grant/
terraform init
terraform plan
terraform apply

# View client configurations and secrets
terraform output password_grant_clients
terraform output password_grant_client_secrets

# View usage example
terraform output usage_example
```

## 📝 Adding Multiple Clients

Each folder supports multiple clients through the `apps.yaml` file. Simply add more entries to the `clients` array:

**Example - Multiple PKCE clients:**
```yaml
clients:
  - client_id: webapp-pkce
    name: Web Application
    # ... config
    
  - client_id: mobile-app-pkce
    name: Mobile Application
    # ... config
    
  - client_id: spa-app-pkce
    name: Single Page App
    # ... config
```

## 🔑 Retrieving Client Credentials

### Get PKCE Client UUIDs
```bash
cd pkce/
terraform output -json pkce_clients | jq '.["webapp-pkce"].client_id'
```

### Get M2M Client Secrets
```bash
cd m2m/
terraform output -json m2m_client_secrets | jq -r '.["backend-service-m2m"]'
```

### Get Password Grant Client Secrets
```bash
cd password-grant/
terraform output -json password_grant_client_secrets | jq -r '.["legacy-app-password"]'
```

## 🔒 Security Features

### 1. Stable UUIDs
- Each client gets a stable UUID generated from its `client_id`
- UUIDs persist across terraform runs (no resource recreation)
- Keepers ensure UUID regeneration only when client_id changes

### 2. Random Secrets (48 characters)
- M2M clients: Auto-generated 48-character secrets
- Password Grant (CONFIDENTIAL): Auto-generated 48-character secrets
- Password Grant (PUBLIC): No secret required
- Minimum requirements: 2 uppercase, 2 lowercase, 2 digits, 2 special chars

### 3. Lifecycle Management
- `ignore_changes = [name]` prevents unnecessary resource recreation
- Secrets stored in Terraform state (mark as sensitive in outputs)

## 🔄 Token Exchange Examples

### PKCE Flow
```bash
# Step 1: Redirect user to authorization URL
https://localhost:8080/realms/customer/protocol/openid-connect/auth?
  client_id=<CLIENT_UUID>&
  redirect_uri=http://localhost:5173/callback&
  response_type=code&
  scope=openid profile email&
  code_challenge=<CODE_CHALLENGE>&
  code_challenge_method=S256

# Step 2: Exchange code for tokens
curl -X POST 'http://localhost:8080/realms/customer/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=authorization_code' \
  -d 'client_id=<CLIENT_UUID>' \
  -d 'code=<AUTHORIZATION_CODE>' \
  -d 'redirect_uri=http://localhost:5173/callback' \
  -d 'code_verifier=<CODE_VERIFIER>'
```

### M2M Flow (Client Credentials)
```bash
curl -X POST 'http://localhost:8080/realms/customer/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=client_credentials' \
  -d 'client_id=<CLIENT_UUID>' \
  -d 'client_secret=<CLIENT_SECRET>' \
  -d 'scope=openid'
```

### Password Grant Flow (ROPC)
```bash
# CONFIDENTIAL client (with secret)
curl -X POST 'http://localhost:8080/realms/customer/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=password' \
  -d 'client_id=<CLIENT_UUID>' \
  -d 'client_secret=<CLIENT_SECRET>' \
  -d 'username=<USER_EMAIL>' \
  -d 'password=<USER_PASSWORD>' \
  -d 'scope=openid profile email'

# PUBLIC client (no secret)
curl -X POST 'http://localhost:8080/realms/customer/protocol/openid-connect/token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'grant_type=password' \
  -d 'client_id=<CLIENT_UUID>' \
  -d 'username=<USER_EMAIL>' \
  -d 'password=<USER_PASSWORD>' \
  -d 'scope=openid profile email'
```

## ⚠️ Security Best Practices

### PKCE Clients
- ✅ Use for web and mobile applications
- ✅ Always use S256 challenge method
- ✅ Configure proper redirect URIs
- ✅ Set appropriate CORS origins
- ✅ Keep token lifespans short (5-10 minutes)

### M2M Clients
- ✅ Use for service-to-service communication only
- ✅ Store client secrets securely (environment variables, secrets manager)
- ✅ Never expose secrets in logs or client-side code
- ✅ Rotate secrets periodically
- ✅ Use appropriate service account roles

### Password Grant Clients
- ⚠️ **ONLY use for legacy application migration**
- ⚠️ Consider migrating to PKCE flow when possible
- ⚠️ User credentials are exposed to the application
- ⚠️ Not recommended for new applications
- ✅ Use CONFIDENTIAL type when possible
- ✅ Keep token lifespans short
- ✅ Implement proper credential storage in app

## 🔧 Troubleshooting

### Issue: UUID changes on every apply
**Solution:** Ensure `keepers` in `random_uuid` resource references the correct `client_id`

### Issue: Client secret not found
**Solution:** Run `terraform output -json m2m_client_secrets` or `password_grant_client_secrets`

### Issue: CORS errors
**Solution:** Add your application origin to `web_origins` in `apps.yaml`

### Issue: Token expired quickly
**Solution:** Adjust `access_token_lifespan` in `token_settings`

### Issue: Password grant not working
**Solution:** Ensure user exists in realm and `direct_access_grants_enabled = true`

## 📚 Additional Resources

- [Keycloak Provider Documentation](https://registry.terraform.io/providers/keycloak/keycloak/latest/docs)
- [OAuth 2.0 PKCE RFC](https://datatracker.ietf.org/doc/html/rfc7636)
- [OAuth 2.0 Client Credentials](https://datatracker.ietf.org/doc/html/rfc6749#section-4.4)
- [OAuth 2.0 Password Grant](https://datatracker.ietf.org/doc/html/rfc6749#section-4.3)
- [Keycloak Documentation](https://www.keycloak.org/documentation)

- **YAML Configuration**: Define clients in `app.yaml` for easy management
- **Stable UUIDs**: Client IDs use random UUIDs to prevent resource destruction when names change
- **Two Client Types**: PKCE (public) and M2M (confidential) flows
- **Automated Setup**: Terraform manages client creation, scopes, and protocol mappers

## Client Types

### 1. PKCE Client (Public)
- **Flow**: Authorization Code + PKCE (S256)
- **Use Case**: Web apps, SPAs, mobile apps, React/Vue/Angular applications
- **Authentication**: No client secret (public client)
- **Security**: PKCE prevents authorization code interception attacks

### 2. M2M Client (Confidential)
- **Flow**: Client Credentials (OAuth 2.0)
- **Use Case**: Service-to-service communication, backend APIs, microservices
- **Authentication**: Client ID (UUID) + Client Secret
- **Security**: Confidential client with service account enabled

## File Structure

```
app/customer/
├── main.tf              # Client resources and random UUID generation
├── variables.tf         # Keycloak connection variables
├── outputs.tf           # Categorized outputs (pkce_clients, m2m_clients)
├── app.yaml            # Client configurations (flows, URIs, tokens)
└── README.md           # This file
```

## Setup

### 1. Configure Clients in `app.yaml`

Edit `app.yaml` to define your OAuth clients:

```yaml
realm: customer  # Target realm name

pkce_client:
  client_id: webapp-pkce           # Keeper ID (stable)
  name: Web Application (PKCE)     # Display name (changeable)
  redirect_uris:
    - http://localhost:5173/callback
  web_origins:
    - http://localhost:5173
  
m2m_client:
  client_id: backend-service-m2m
  name: Backend Service (M2M)
  client_secret: "your-secure-secret-32chars-min"
```

### 2. Set Keycloak Connection

Create/update `terraform.tfvars`:

```hcl
keycloak_url          = "http://localhost:8080"
keycloak_username     = "admin"
keycloak_password     = "admin"
keycloak_client_id    = "admin-cli"
keycloak_admin_realm  = "master"
```

### 3. Deploy Clients

```bash
# Initialize Terraform and install providers
terraform init

# Review what will be created
terraform plan

# Create the clients
terraform apply
```

## Client Configuration Architecture

### Random UUID Generation

Each client gets a stable UUID that persists across name changes:

```hcl
resource "random_uuid" "pkce_client" {
  keepers = {
    client_id = local.pkce_config.client_id  # From app.yaml
  }
}
```

The UUID only changes if you modify the `client_id` in `app.yaml`, not the display name.

### Lifecycle Management

```hcl
lifecycle {
  ignore_changes = [name]  # Allows name changes without recreation
}
```

## Viewing Client Configurations

### Categorized Outputs

All clients are organized by type:

```bash
# View all PKCE clients
terraform output pkce_clients

# View all M2M clients (sensitive)
terraform output m2m_clients

# View M2M secrets separately
terraform output m2m_client_secrets
```

### JSON Output

```bash
# Get PKCE webapp configuration
terraform output -json pkce_clients | jq '.webapp'

# Get M2M backend service configuration
terraform output -json m2m_clients | jq '.backend_service'

# Extract specific field
terraform output -json pkce_clients | jq -r '.webapp.client_id'
terraform output -json pkce_clients | jq -r '.webapp.authorization_url'
```

### Get Client Secrets

M2M client secrets are stored separately as sensitive values:

```bash
# View all M2M client secrets (masked by default)
terraform output m2m_client_secrets

# Get raw secret value for backend service
terraform output -raw m2m_client_secrets | jq -r '.backend_service'

# Or get it from the m2m_clients output (includes full client config)
terraform output -json m2m_clients | jq -r '.backend_service.client_id'

# Copy secret to clipboard (macOS)
terraform output -raw m2m_client_secrets | jq -r '.backend_service' | pbcopy

# Copy secret to clipboard (Linux with xclip)
terraform output -raw m2m_client_secrets | jq -r '.backend_service' | xclip -selection clipboard

# Save secrets to a secure file (use with caution!)
terraform output -json m2m_client_secrets > secrets.json
chmod 600 secrets.json  # Restrict file permissions
```

**Security Warning**: Never commit secrets to version control or share them in plain text. Use secure methods like:
- Environment variables
- Secret management tools (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault)
- Encrypted storage
- Password managers

### Sample Output Structure

```json
{
  "pkce_clients": {
    "webapp": {
      "client_id": "2e8ae84f-d459-8ecd-52cb-e2c46fa76eb2",
      "client_name": "Web Application (PKCE)",
      "client_type": "PUBLIC",
      "flow_type": "Authorization Code + PKCE",
      "pkce_method": "S256",
      "authorization_url": "http://localhost:8080/realms/customer/protocol/openid-connect/auth",
      "token_url": "http://localhost:8080/realms/customer/protocol/openid-connect/token",
      "userinfo_url": "http://localhost:8080/realms/customer/protocol/openid-connect/userinfo",
      "logout_url": "http://localhost:8080/realms/customer/protocol/openid-connect/logout",
      "redirect_uris": ["http://localhost:5173/callback"],
      "web_origins": ["http://localhost:5173"],
      "scopes": ["openid", "profile", "email"]
    }
  },
  "m2m_clients": {
    "backend_service": {
      "client_id": "529d24ed-e037-3929-7c3f-78b5acd70804",
      "client_name": "Backend Service (M2M)",
      "client_type": "CONFIDENTIAL",
      "flow_type": "Client Credentials",
      "grant_type": "client_credentials",
      "token_url": "http://localhost:8080/realms/customer/protocol/openid-connect/token",
      "scopes": ["openid"]
    }
  }
}
```

## Usage Examples

### PKCE Flow (Web/Mobile Apps)

#### 1. Generate PKCE Challenge

```javascript
// JavaScript example
function generateCodeVerifier() {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return base64UrlEncode(array);
}

async function generateCodeChallenge(verifier) {
  const encoder = new TextEncoder();
  const data = encoder.encode(verifier);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return base64UrlEncode(new Uint8Array(hash));
}
```

#### 2. Authorization Request

```javascript
const authUrl = new URL('http://localhost:8080/realms/customer/protocol/openid-connect/auth');
authUrl.searchParams.append('client_id', '2e8ae84f-d459-8ecd-52cb-e2c46fa76eb2');
authUrl.searchParams.append('redirect_uri', 'http://localhost:5173/callback');
authUrl.searchParams.append('response_type', 'code');
authUrl.searchParams.append('scope', 'openid profile email');
authUrl.searchParams.append('code_challenge', codeChallenge);
authUrl.searchParams.append('code_challenge_method', 'S256');

window.location.href = authUrl.toString();
```

#### 3. Token Exchange

```bash
curl -X POST http://localhost:8080/realms/customer/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code" \
  -d "client_id=2e8ae84f-d459-8ecd-52cb-e2c46fa76eb2" \
  -d "code=<authorization_code>" \
  -d "redirect_uri=http://localhost:5173/callback" \
  -d "code_verifier=<code_verifier>"
```

### M2M Flow (Service-to-Service)

#### Get Access Token

```bash
curl -X POST http://localhost:8080/realms/customer/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=529d24ed-e037-3929-7c3f-78b5acd70804" \
  -d "client_secret=your-secure-client-secret-here-change-me-32chars" \
  -d "grant_type=client_credentials"
```

#### Response

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 3600,
  "token_type": "Bearer",
  "scope": "openid"
}
```

#### Use Token

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/realms/customer/protocol/openid-connect/token \
  -d "client_id=529d24ed-e037-3929-7c3f-78b5acd70804" \
  -d "client_secret=your-secret" \
  -d "grant_type=client_credentials" | jq -r .access_token)

curl -H "Authorization: Bearer $TOKEN" https://your-api.com/protected
```

## Adding New Clients

### Add PKCE Client

Edit `app.yaml` and add to the `pkce_client` section or duplicate the structure:

```yaml
pkce_client:
  mobile_app:
    client_id: mobile-app-pkce
    name: Mobile Application
    redirect_uris:
      - myapp://callback
    web_origins:
      - "*"
```

Then update `main.tf` to create the new client resource.

### Add M2M Client

Add to `app.yaml`:

```yaml
m2m_client:
  analytics_service:
    client_id: analytics-service-m2m
    name: Analytics Service
    client_secret: "another-secure-secret"
```

## Security Best Practices

### PKCE Clients

- ✅ Always use PKCE with S256 (SHA-256)
- ✅ Validate redirect URIs strictly (no wildcards in production)
- ✅ Keep access token lifespan short (5-15 minutes)
- ✅ Use refresh tokens for long-lived sessions
- ✅ Implement proper token validation in your app
- ✅ Enable CORS only for specific origins

### M2M Clients

- ✅ Generate strong secrets (minimum 32 characters, use random provider)
- ✅ Rotate secrets regularly (e.g., every 90 days)
- ✅ Store secrets in secure vaults (Azure Key Vault, AWS Secrets Manager, HashiCorp Vault)
- ✅ Never commit secrets to version control
- ✅ Limit service account permissions (principle of least privilege)
- ✅ Monitor and audit token usage
- ✅ Use short-lived tokens when possible

### General

- ✅ Always use HTTPS in production
- ✅ Implement rate limiting
- ✅ Enable brute force detection in Keycloak
- ✅ Set appropriate token lifespans
- ✅ Use audience validation
- ✅ Implement proper error handling (don't leak information)

## Configuration Reference

### app.yaml Structure

```yaml
realm: customer  # Target realm

pkce_client:
  client_id: webapp-pkce            # Stable keeper ID
  name: Web Application (PKCE)      # Display name
  enabled: true
  
  flows:
    standard_flow: true             # Authorization Code
    direct_access_grants: false     # ROPC (not recommended)
    implicit_flow: false            # Deprecated
    service_accounts: false         # Not for PKCE
  
  pkce:
    challenge_method: S256          # SHA-256 only
  
  redirect_uris:
    - http://localhost:5173/callback
  
  web_origins:
    - http://localhost:5173         # CORS allowed origins
  
  token_settings:
    access_token_lifespan: 300      # 5 minutes
    session_idle_timeout: 1800      # 30 minutes
    session_max_lifespan: 36000     # 10 hours
  
  consent_required: false

m2m_client:
  client_id: backend-service-m2m
  name: Backend Service (M2M)
  enabled: true
  
  flows:
    standard_flow: false
    service_accounts: true          # Enable client credentials
  
  client_secret: "secure-32-char-secret-here"
  
  token_settings:
    access_token_lifespan: 3600     # 1 hour
  
  service_account_roles: []         # Optional realm roles
```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **Invalid redirect URI** | Add exact URI to `redirect_uris` in app.yaml |
| **CORS errors** | Add origin to `web_origins` in app.yaml |
| **M2M unauthorized** | Verify client secret and ensure `service_accounts: true` |
| **Token expired** | Adjust `token_settings.access_token_lifespan` |
| **Client not found** | Check realm name matches in app.yaml and tfvars |
| **Resource recreated on apply** | UUID keepers prevent this; check if `client_id` in app.yaml changed |

### Debug Commands

```bash
# Check Terraform state
terraform show

# View specific resource
terraform state show keycloak_openid_client.pkce_client

# Get raw output
terraform output -raw pkce_clients

# Refresh state
terraform refresh

# Import existing client (if needed)
terraform import keycloak_openid_client.pkce_client customer/client-uuid
```

## Client Libraries

### JavaScript/TypeScript
- `keycloak-js` - Official Keycloak adapter
- `oidc-client-ts` - Certified OpenID Connect client
- `@react-keycloak/web` - React integration
- `keycloak-angular` - Angular integration

### Python
- `python-keycloak` - Keycloak admin and auth client
- `authlib` - OAuth/OIDC client library

### Java
- `keycloak-spring-boot-starter` - Spring Boot integration
- `keycloak-servlet-filter-adapter` - Servlet filter

### .NET
- `Keycloak.AuthServices.Authentication` - ASP.NET Core

## Related Configurations

- **Users**: `/Users/kraaj/Projects/HomeLab/DevOps/SSO/users/customer/`
- **Admin Users**: `/Users/kraaj/Projects/HomeLab/DevOps/SSO/users/admin/`

## Resources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OAuth 2.0 PKCE RFC](https://tools.ietf.org/html/rfc7636)
- [OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html)
- [Terraform Keycloak Provider](https://registry.terraform.io/providers/keycloak/keycloak/latest/docs)
