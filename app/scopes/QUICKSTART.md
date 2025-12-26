# Quick Start Guide - Custom Client Scopes

## Overview

This module creates custom OpenID Connect client scopes in Keycloak using YAML configuration.

## Quick Setup (5 minutes)

### 1. Configure Credentials

```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your Keycloak credentials
nano terraform.tfvars
```

### 2. Customize Scopes (Optional)

Edit `scopes.yaml` to add/modify scopes:

```yaml
scopes:
  - name: my-custom-scope
    description: My custom scope
    protocol: openid-connect
    include_in_token_scope: true

    mappers:
      - name: my-claim
        protocol: openid-connect
        protocol_mapper: oidc-hardcoded-claim-mapper
        config:
          claim.name: custom_claim
          claim.value: custom_value
          jsonType.label: String
          access.token.claim: true
```

### 3. Deploy

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply configuration
terraform apply
```

### 4. Verify

```bash
# View created scopes
terraform output scope_names

# View scope details
terraform output scopes

# View mapper statistics
terraform output mapper_counts
```

## What Gets Created

The default configuration creates 5 scopes:

| Scope | Purpose | Mappers |
|-------|---------|---------|
| `user-profile` | User profile claims | username, email, email_verified, full_name |
| `user-roles` | Role claims | realm_roles, client_roles |
| `organization` | Organization data | organization_id, department, tenant |
| `api-permissions` | API access | api_scopes, permissions |
| `audit-info` | Audit tracking | issued_at, session_id |

## Common Use Cases

### Use Case 1: Attach Scope to Existing Client

After creating scopes, attach them to a client:

```bash
# In Keycloak Admin UI:
# 1. Go to Clients → [Your Client]
# 2. Click "Client Scopes" tab
# 3. Click "Add client scope"
# 4. Select your custom scopes
# 5. Choose "Default" or "Optional"
```

Or via Terraform:

```hcl
resource "keycloak_openid_client_default_scopes" "my_client_scopes" {
  realm_id  = "customer"
  client_id = "your-client-id"

  default_scopes = [
    "openid",
    "user-profile",
    "organization"
  ]
}
```

### Use Case 2: Create Scope for Microservices

Add a microservice-specific scope:

```yaml
- name: service-metadata
  description: Microservice metadata claims
  protocol: openid-connect
  include_in_token_scope: true

  mappers:
    - name: service-name
      protocol: openid-connect
      protocol_mapper: oidc-hardcoded-claim-mapper
      config:
        claim.name: service_name
        claim.value: user-service
        jsonType.label: String
        access.token.claim: true

    - name: service-version
      protocol: openid-connect
      protocol_mapper: oidc-hardcoded-claim-mapper
      config:
        claim.name: service_version
        claim.value: v1.0.0
        jsonType.label: String
        access.token.claim: true
```

### Use Case 3: Multi-Tenant Claims

Add tenant isolation claims:

```yaml
- name: tenant-isolation
  description: Tenant isolation claims
  protocol: openid-connect
  include_in_token_scope: true

  mappers:
    - name: tenant-id
      protocol: openid-connect
      protocol_mapper: oidc-usermodel-attribute-mapper
      config:
        user.attribute: tenant_id
        claim.name: tenant_id
        jsonType.label: String
        access.token.claim: true

    - name: tenant-roles
      protocol: openid-connect
      protocol_mapper: oidc-usermodel-attribute-mapper
      config:
        user.attribute: tenant_roles
        claim.name: tenant_roles
        jsonType.label: JSON
        access.token.claim: true
```

## Integration with M2M Module

### Step 1: Create Scopes First

```bash
cd app/scopes
terraform apply
```

### Step 2: Note Scope IDs

```bash
terraform output scope_ids
# Output:
# {
#   "user-profile" = "scope-uuid-1"
#   "organization" = "scope-uuid-2"
# }
```

### Step 3: Reference in M2M Clients

In your M2M client configuration, you can manually attach these scopes via Keycloak admin UI or create additional Terraform resources.

## Token Examples

### Before (Standard OpenID Token)

```json
{
  "sub": "user-123",
  "aud": "my-app",
  "exp": 1735128000
}
```

### After (With Custom Scopes)

```json
{
  "sub": "user-123",
  "aud": "my-app",
  "exp": 1735128000,
  "preferred_username": "john.doe",
  "email": "john.doe@example.com",
  "email_verified": true,
  "name": "John Doe",
  "realm_access": {
    "roles": ["user", "admin"]
  },
  "org_id": "org-123",
  "department": "Engineering",
  "tenant": "default-tenant",
  "permissions": ["read:users", "write:users"]
}
```

## Troubleshooting

### Issue: Scopes created but not appearing in tokens

**Solution**: Ensure scopes are attached to the client and requested in the authorization request:

```bash
# Authorization request should include scope parameter
https://keycloak.example.com/realms/customer/protocol/openid-connect/auth?
  client_id=my-client&
  scope=openid user-profile organization&
  ...
```

### Issue: Mapper not adding claims to token

**Solution**: Check mapper configuration:
- Verify `access.token.claim: true` is set
- Ensure user has the attribute (for user-attribute mappers)
- Check that `include_in_token_scope: true` on the scope

### Issue: Terraform errors about missing config keys

**Solution**: Ensure YAML config keys use dots:
```yaml
# Correct
config:
  claim.name: my_claim

# Incorrect
config:
  claim_name: my_claim
```

## Next Steps

1. **Test Token Claims**: Request a token and decode it to verify claims
2. **Attach to Clients**: Add scopes to your application clients
3. **Customize**: Modify `scopes.yaml` for your specific needs
4. **Document**: Keep track of which scopes are used by which clients

## References

- [Main README](./README.md) - Detailed documentation
- [Keycloak Scopes Documentation](https://www.keycloak.org/docs/latest/server_admin/#_client_scopes)
- [M2M Module](../m2m/) - M2M client configuration
