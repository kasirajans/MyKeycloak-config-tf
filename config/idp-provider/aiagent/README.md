# Okta Identity Provider Configuration for AIAgent Realm

This module configures Okta as an OpenID Connect (OIDC) Identity Provider in the AIAgent realm, enabling OAuth 2.0 Token Exchange (RFC 8693) flows.

## Prerequisites

1. **Okta Tenant** - You must have an Okta account with an organization
2. **Okta Application** - Create an application in Okta with:
   - Client ID
   - Client Secret
   - Scopes: `openid profile email okta.users.read okta.groups.read`
3. **Keycloak** - Running instance with admin access

## Setup Steps

### Step 1: Get Okta Application Details

1. Log in to your Okta Admin Console
2. Go to **Applications** → **Applications**
3. Click on your application (or create a new one)
4. Copy the **Client ID** (okta_client_secret is optional - see note below)
5. Update `idpprovider.yml`:
   - Replace `0oas980xvuk2k3RhO697` with your Okta Client ID
   - Replace `trial-2447193.okta.com` with your Okta domain (e.g., `company.okta.com`)
   - Leave `client_secret: null` for token exchange (no secret needed)

**Note**: For token exchange, you DO NOT need the Okta client secret because Keycloak validates tokens using Okta's public JWKS keys, not by calling Okta APIs.

### Step 2: Configure Terraform Variables

```bash
# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# For token exchange, leave okta_client_secret empty
# terraform.tfvars:
okta_client_secret = ""  # Empty is fine for token exchange

# Update Keycloak credentials as needed
# terraform.tfvars:
keycloak_password = "your_keycloak_admin_password"
```

### Step 3: Deploy the Identity Provider

```bash
# Initialize Terraform (if first time)
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### Step 4: Add Attribute Mappers (Manual Configuration)

The keycloak provider doesn't support OIDC attribute mappers directly, so you need to add them manually:

**Via Keycloak Admin Console**:
1. Go to **Identity Providers** → **okta-oidc** → **Mappers** tab
2. Click **Create** and add each mapper:

| Name | Mapper Type | Claim Name | User Attribute | Sync Mode |
|------|-------------|-----------|-----------------|-----------|
| sub | User Attribute Mapper | sub | sub | INHERIT |
| email | User Attribute Mapper | email | email | INHERIT |
| firstName | User Attribute Mapper | given_name | firstName | INHERIT |
| lastName | User Attribute Mapper | family_name | lastName | INHERIT |
| username | User Attribute Mapper | preferred_username | username | INHERIT |
| appRoles | User Attribute Mapper | appRoles | appRoles | INHERIT |
| groups | User Attribute Mapper | groups | groups | INHERIT |
| okta_domain | User Attribute Mapper | iss | okta_domain | INHERIT |

**Or via REST API**:
```bash
# Get admin token
ADMIN_TOKEN=$(curl -s -X POST "http://localhost:9090/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=admin-cli" \
  -d "client_secret=<admin-secret>" | jq -r '.access_token')

# Add a mapper (example for 'email' claim)
curl -X POST "http://localhost:9090/admin/realms/AIAgent/identity-provider/instances/okta-oidc/mappers" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "email",
    "identityProviderAlias": "okta-oidc",
    "identityProviderMapper": "oidc-user-attribute-mapper",
    "config": {
      "claim": "email",
      "user.attribute": "email",
      "syncMode": "INHERIT"
    }
  }'
```

### Step 5: Verify Configuration

```bash
# View the configured Okta IdP alias and details
terraform output okta_idp_details

# View mapper reference for manual configuration
terraform output mapper_reference
```

## File Structure

- **idpprovider.yml** - YAML configuration for Okta OIDC provider with attribute mappers
- **main.tf** - Terraform resources to create the IdP and mappers in Keycloak
- **variables.tf** - Input variables for Keycloak and Okta credentials
- **outputs.tf** - Output values showing IdP configuration details
- **terraform.tfvars.example** - Example configuration file

## Configuration Details

### Why No Client Secret for Token Exchange?

For **pure token exchange** flows, Keycloak does NOT need the Okta client secret. Here's why:

1. **JWKS Validation** (Public): Keycloak validates Okta token signatures using Okta's public JWKS endpoint (`/oauth2/v1/keys`)
   - These are public keys - no authentication needed
   - Signature validation happens locally in Keycloak

2. **Token Exchange Process**:
   - AgentResource client sends: Okta access token + exchange parameters
   - Keycloak validates token signature using public JWKS keys
   - Keycloak issues its own access token (with Keycloak scopes)
   - No API calls to Okta needed

3. **When You DO Need client_secret**:
   - Keycloak needs to call Okta's userinfo endpoint to sync user data
   - Using Okta as a broker for user login/signup
   - Implementing backchannel logout
   - Token revocation checks

### IdP Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `alias` | `okta-oidc` | Unique identifier for the IdP |
| `enabled` | `true` | IdP is active |
| `client_id` | Your Okta App Client ID | Identifies Keycloak to Okta (if needed) |
| `client_secret` | (empty) | Not needed for pure token exchange |
| `validate_signature` | `true` | Validate token signatures using public JWKS |
| `store_token` | `true` | Store tokens for later use |
| `sync_mode` | `FORCE` | Keep user data in sync |

### OIDC Endpoints

All endpoints are derived from your Okta domain:

```
Base Domain:  https://trial-2447193.okta.com
Auth URL:     https://trial-2447193.okta.com/oauth2/v1/authorize
Token URL:    https://trial-2447193.okta.com/oauth2/v1/token
JWKS URL:     https://trial-2447193.okta.com/oauth2/v1/keys
Userinfo URL: https://trial-2447193.okta.com/oauth2/v1/userinfo
```

### Scopes

The configuration uses these Okta scopes:
- `openid` - OIDC standard
- `profile` - User profile claims (name, picture, etc.)
- `email` - Email claim
- `okta.users.read` - Read user information
- `okta.groups.read` - Read group memberships

### Attribute Mappers

Maps Okta token claims to Keycloak user attributes:

| Okta Claim | Keycloak Attribute | Purpose |
|------------|-------------------|---------|
| `sub` | `sub` | Unique user identifier |
| `email` | `email` | User email address |
| `given_name` | `firstName` | First name |
| `family_name` | `lastName` | Last name |
| `preferred_username` | `username` | Username for login |
| `appRoles` | `appRoles` | Application roles from Okta |
| `groups` | `groups` | User's groups from Okta |
| `iss` | `okta_domain` | Okta domain identifier |

## Token Exchange Flow

With this IdP configured, the token exchange flow works as follows:

1. **Client Authentication**: AgentResource client provides credentials to Keycloak
2. **Subject Token**: Okta access token is provided as the subject token
3. **Token Validation**: Keycloak validates the Okta token signature using Okta's JWKS endpoint
4. **User Sync**: If valid, Keycloak syncs user attributes from Okta (if needed)
5. **Token Exchange**: Keycloak issues a new access token with Keycloak scopes
6. **Response**: AgentResource client receives the Keycloak access token

Request example:
```bash
curl -X POST "http://localhost:9090/realms/AIAgent/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" \
  -d "client_id=aiagent_AgentResource_mcpServer" \
  -d "client_secret=<client-secret>" \
  -d "subject_token=<okta-access-token>" \
  -d "subject_token_type=urn:ietf:params:oauth:token-type:access_token" \
  -d "requested_token_type=urn:ietf:params:oauth:token-type:access_token" \
  -d "audience=resource-a-server" \
  -d "scope=pd:user:read"
```

## Troubleshooting

### Token Exchange Fails with "subject_token validation failure"

**Cause**: Keycloak couldn't validate the Okta token signature

**Fix**:
1. Verify Okta domain is correct in `idpprovider.yml`
2. Verify `validate_signature = true` in the provider configuration
3. Check that the JWKS URL is accessible: `https://trial-2447193.okta.com/oauth2/v1/keys`
4. Ensure the Okta token hasn't expired

### IdP Not Showing in Admin Console

**Cause**: IdP wasn't created or Terraform didn't apply

**Fix**:
```bash
terraform apply
# Check the state
terraform state list
terraform state show 'keycloak_oidc_identity_provider.providers["okta-oidc"]'
```

### User Information Not Syncing

**Cause**: `sync_mode` may be set incorrectly or user doesn't have required attributes in Okta

**Fix**:
1. Check Okta user profile has all required attributes (email, name, etc.)
2. Verify `sync_mode = "FORCE"` in `idpprovider.yml`
3. Test user login in Keycloak to trigger sync

## Additional Resources

- [Keycloak OIDC Identity Provider Documentation](https://www.keycloak.org/docs/latest/server_admin/#oidc-identity-providers)
- [Okta OIDC Documentation](https://developer.okta.com/docs/reference/api/oidc/)
- [RFC 8693 - OAuth 2.0 Token Exchange](https://tools.ietf.org/html/rfc8693)
- [Keycloak Token Exchange](https://www.keycloak.org/docs/latest/server_admin/#_token_exchange)

## Related Modules

- `/app/aiAgent` - AgentResource client configuration for token exchange
- `/app/scopes` - Custom scopes (`pd:user:read`) for token exchange
- `/config/idp-provider/sp-customer` - Example SP-Customer IdP configuration

## Next Steps

After deploying the Okta IdP:

1. Test token exchange with Okta tokens
2. Verify user attributes are syncing correctly
3. Configure additional role mappers if needed
4. Set up first-broker-login flow customizations
5. Configure backchannel logout if using Okta logout flows
