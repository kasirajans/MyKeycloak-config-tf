# M2M (Machine-to-Machine) Clients Module

This module manages confidential OAuth 2.0 clients using the Client Credentials grant for service-to-service authentication.

## 📋 Overview

M2M clients are used for:
- Backend service authentication
- API-to-API communication
- Service accounts
- Automated processes

**Key Features:**
- ✅ Confidential clients with auto-generated 48-character secrets
- ✅ Client Credentials grant (`grant_type=client_credentials`)
- ✅ Custom client scopes support
- ✅ Service account roles
- ✅ UUID-based client IDs for security

## 🚀 Quick Start

### 1. Deploy Scopes (if using custom scopes)

```bash
cd ../scopes
terraform init
terraform apply -auto-approve
```

### 2. Deploy M2M Clients

```bash
cd ../m2m
terraform init
terraform apply -auto-approve
```

### 3. Get Client Credentials

```bash
# View all clients
terraform output m2m_clients

# Get specific client info
terraform output -json m2m_clients | jq '.["aiagent-okta-m2m"]'

# Get client secret
terraform output -json m2m_client_secrets | jq -r '.["aiagent-okta-m2m"]'
```

## ⚙️ Configuration

### File: `apps.yaml`

```yaml
realm: AIAgent

clients:
  - client_id: aiagent-okta-m2m
    name: AIAgent - Okta Integration (M2M)
    description: AIAgent service account for Okta API user management
    enabled: true

    # Token settings (in seconds)
    token_settings:
      access_token_lifespan: 1800  # 30 minutes

    # Service account roles (optional)
    service_account_roles: []
      # - view-users
      # - manage-users

    # Client scopes (from scopes module)
    default_scopes: []              # Auto-included in every token
    optional_scopes: ["okta-api-access"]  # Must be requested with scope parameter
```

## 🔑 Getting Access Tokens

### Using Terraform Outputs

```bash
# Extract credentials
CLIENT_ID=$(terraform output -json m2m_clients | jq -r '.["aiagent-okta-m2m"].client_id')
CLIENT_SECRET=$(terraform output -json m2m_client_secrets | jq -r '.["aiagent-okta-m2m"]')
TOKEN_URL=$(terraform output -json m2m_clients | jq -r '.["aiagent-okta-m2m"].token_url')

# Get access token (with optional scope)
curl -X POST "$TOKEN_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=okta-api-access"
```

### Response

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 1800,
  "token_type": "Bearer",
  "scope": "okta-api-access"
}
```

## 📊 Token Claims

When using the `okta-api-access` scope, the access token contains:

```json
{
  "exp": 1735238400,
  "iat": 1735236600,
  "jti": "uuid",
  "iss": "https://keycloak/realms/AIAgent",
  "aud": "okta-api",
  "sub": "service-account-uuid",
  "typ": "Bearer",
  "azp": "client-uuid",

  "okta_scopes": [
    "okta.users.read",
    "okta.users.manage",
    "okta.groups.read",
    "okta.groups.manage"
  ],
  "agent_id": "ai-agent-okta-integration",
  "okta_domain": "your-okta-domain.okta.com",
  "integration_type": "okta_user_management",
  "okta_api_version": "v1",
  "rate_limit_tier": "standard"
}
```

## 🔧 Configuration Options

### Token Settings

```yaml
token_settings:
  access_token_lifespan: 1800  # In seconds (30 minutes)
```

### Service Account Roles

Assign realm roles to the service account:

```yaml
service_account_roles:
  - view-users
  - manage-users
  - realm-admin
```

### Client Scopes

#### Default Scopes
Automatically included in every token (no scope parameter needed):

```yaml
default_scopes:
  - okta-api-access
  - audit-info
```

**Token Request:**
```bash
curl -X POST "$TOKEN_URL" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET"
# No scope parameter needed - default scopes are automatic
```

#### Optional Scopes
Must be explicitly requested:

```yaml
optional_scopes:
  - okta-api-access
  - additional-permissions
```

**Token Request:**
```bash
curl -X POST "$TOKEN_URL" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=okta-api-access additional-permissions"  # Required
```

## 📝 Adding New M2M Clients

### 1. Edit `apps.yaml`

```yaml
clients:
  - client_id: my-backend-service
    name: My Backend Service (M2M)
    description: Backend service for API communication
    enabled: true

    token_settings:
      access_token_lifespan: 3600  # 1 hour

    service_account_roles: []

    default_scopes:
      - api-permissions
    optional_scopes: []
```

### 2. Apply Changes

```bash
terraform apply
```

### 3. Retrieve Credentials

```bash
terraform output -json m2m_clients | jq '.["my-backend-service"]'
terraform output -json m2m_client_secrets | jq -r '.["my-backend-service"]'
```

## 🔍 Viewing Outputs

### All Clients

```bash
terraform output m2m_clients
```

### Specific Client Configuration

```bash
terraform output -json m2m_clients | jq '.["aiagent-okta-m2m"]'
```

Output:
```json
{
  "client_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "client_name": "AIAgent - Okta Integration (M2M)",
  "client_type": "CONFIDENTIAL",
  "flow_type": "Client Credentials",
  "grant_type": "client_credentials",
  "internal_id": "keycloak-internal-id",
  "resource_uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "scope_id": "scope-internal-id",
  "service_account_user_id": "service-account-user-id",
  "token_url": "https://keycloak/realms/AIAgent/protocol/openid-connect/token",
  "scopes": ["openid"]
}
```

### Client Secrets

```bash
terraform output -json m2m_client_secrets | jq -r '.["aiagent-okta-m2m"]'
```

**Note**: Secrets are marked as `sensitive = true` and won't display in normal output.

### Realm Name

```bash
terraform output realm_name
```

## 🔒 Security

### Client Secret Generation

- Auto-generated using `random_password` resource
- **Length**: 48 characters
- **Includes**: Uppercase, lowercase, numbers, special characters
- **Special characters**: `!@#$%^&*()-_=+[]{}:,.<>?`
- **Minimums**: 2 uppercase, 2 lowercase, 2 numeric, 2 special

### Client ID (UUID)

- Generated using `random_uuid` resource
- Stable across Terraform runs (uses `keepers`)
- More secure than human-readable client IDs

### Best Practices

1. **Store secrets securely**: Use secret managers (AWS Secrets Manager, HashiCorp Vault, etc.)
2. **Rotate secrets regularly**: Update via Terraform or Keycloak admin console
3. **Use short token lifespans**: 15-30 minutes for sensitive operations
4. **Limit scopes**: Only assign necessary scopes to each client
5. **Monitor usage**: Track service account activity via Keycloak logs

## 🛠️ Troubleshooting

### "Output 'clients' not found"

**Problem**: Running `terraform output -json clients`

**Solution**: Use the correct output name:
```bash
terraform output -json m2m_clients  # Correct
```

### "Client authentication failed"

**Problem**: Token request returns 401

**Solution**:
1. Verify client_id from `terraform output -json m2m_clients`
2. Verify client_secret from `terraform output -json m2m_client_secrets`
3. Ensure using `grant_type=client_credentials`
4. Check client is enabled in `apps.yaml`

### "Scope not found" or "Invalid scope"

**Problem**: Scope referenced in `apps.yaml` doesn't exist

**Solution**:
1. Deploy scopes module first: `cd ../scopes && terraform apply`
2. Verify scope name matches `scopes.yaml` exactly
3. Check realm matches between `apps.yaml` and `scopes.yaml`
4. Run `terraform plan` to see data source resolution

### Token doesn't contain expected claims

**Problem**: Claims from scope are missing

**Solution**:
- **Default scopes**: Claims should be automatic - check scope is in `default_scopes` list
- **Optional scopes**: Must request with `scope=scope-name` parameter
- Verify scope mappers are configured in `scopes.yaml`
- Check `access.token.claim: true` in mapper config

### "Error: Cycle" during terraform plan

**Problem**: Circular dependency between modules

**Solution**:
1. Deploy in order: `scopes` → `m2m`
2. Don't create scopes and clients in same root module
3. Use data sources (not module outputs) to reference scopes

## 📊 Terraform Resources

This module creates:

- `keycloak_openid_client.m2m` - M2M client
- `random_uuid.client` - Client UUID
- `random_password.client_secret` - Client secret (48 chars)
- `keycloak_openid_client_scope.m2m_scope` - Custom scope per client
- `keycloak_openid_client_service_account_role.m2m_role` - Service account role assignments
- `keycloak_openid_audience_protocol_mapper.m2m_audience` - Audience mapper
- `keycloak_openid_client_default_scopes.default` - Default scope attachments
- `keycloak_openid_client_optional_scopes.optional` - Optional scope attachments

## 🔗 Related

- **Scopes Module**: See `../scopes/` for creating custom scopes
- **PKCE Clients**: See `../pkce/` for public clients
- **Main README**: See `../README.md` for complete overview
