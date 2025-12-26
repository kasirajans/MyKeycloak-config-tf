# Keycloak Custom Client Scopes

This Terraform module manages Keycloak custom client scopes using a YAML-driven configuration approach.

## Overview

Client scopes in Keycloak are used to define sets of protocol mappers and role scope mappings that can be shared across multiple clients. This module allows you to:

- Define custom client scopes declaratively via YAML
- Configure protocol mappers (claims) for each scope
- Control which claims appear in ID tokens, access tokens, and userinfo endpoints
- Manage consent screen settings

## File Structure

```
scopes/
├── scopes.yaml      # YAML configuration file
├── main.tf          # Terraform resources
├── variables.tf     # Input variables
├── outputs.tf       # Output values
└── README.md        # This file
```

## YAML Configuration Format

### Basic Scope Structure

```yaml
realm: customer

scopes:
  - name: scope-name
    description: Scope description
    protocol: openid-connect

    # Scope settings
    include_in_token_scope: true
    display_on_consent_screen: true
    consent_screen_text: "Text shown on consent screen"
    gui_order: 1

    # Protocol mappers
    mappers:
      - name: mapper-name
        protocol: openid-connect
        protocol_mapper: mapper-type
        config:
          # Mapper-specific configuration
```

### Supported Protocol Mappers

#### 1. User Property Mapper (`oidc-usermodel-property-mapper`)
Maps built-in user properties (username, email, etc.) to claims.

```yaml
- name: email
  protocol: openid-connect
  protocol_mapper: oidc-usermodel-property-mapper
  config:
    user.attribute: email
    claim.name: email
    jsonType.label: String
    id.token.claim: true
    access.token.claim: true
    userinfo.token.claim: true
```

#### 2. User Attribute Mapper (`oidc-usermodel-attribute-mapper`)
Maps custom user attributes to claims.

```yaml
- name: organization-id
  protocol: openid-connect
  protocol_mapper: oidc-usermodel-attribute-mapper
  config:
    user.attribute: organization_id
    claim.name: org_id
    jsonType.label: String
    id.token.claim: false
    access.token.claim: true
    userinfo.token.claim: true
```

#### 3. Full Name Mapper (`oidc-full-name-mapper`)
Maps user's full name to the `name` claim.

```yaml
- name: full-name
  protocol: openid-connect
  protocol_mapper: oidc-full-name-mapper
  config:
    id.token.claim: true
    access.token.claim: true
    userinfo.token.claim: true
```

#### 4. Hardcoded Claim Mapper (`oidc-hardcoded-claim-mapper`)
Adds a hardcoded claim with a static value.

```yaml
- name: tenant
  protocol: openid-connect
  protocol_mapper: oidc-hardcoded-claim-mapper
  config:
    claim.name: tenant
    claim.value: default-tenant
    jsonType.label: String
    id.token.claim: false
    access.token.claim: true
    userinfo.token.claim: false
```

#### 5. User Realm Role Mapper (`oidc-usermodel-realm-role-mapper`)
Maps user's realm roles to claims.

```yaml
- name: realm-roles
  protocol: openid-connect
  protocol_mapper: oidc-usermodel-realm-role-mapper
  config:
    claim.name: realm_access.roles
    jsonType.label: String
    multivalued: true
    access.token.claim: true
```

#### 6. User Client Role Mapper (`oidc-usermodel-client-role-mapper`)
Maps user's client roles to claims.

```yaml
- name: client-roles
  protocol: openid-connect
  protocol_mapper: oidc-usermodel-client-role-mapper
  config:
    claim.name: resource_access.${client_id}.roles
    jsonType.label: String
    multivalued: true
    access.token.claim: true
```

#### 7. Audience Mapper (`oidc-audience-mapper`)
Adds custom audience to tokens.

```yaml
- name: api-audience
  protocol: openid-connect
  protocol_mapper: oidc-audience-mapper
  config:
    included.custom.audience: api-backend
    id.token.claim: false
    access.token.claim: true
```

#### 8. User Session Note Mapper (`oidc-usersessionmodel-note-mapper`)
Maps session notes to claims.

```yaml
- name: session-id
  protocol: openid-connect
  protocol_mapper: oidc-usersessionmodel-note-mapper
  config:
    user.session.note: session_id
    claim.name: sid
    jsonType.label: String
    id.token.claim: true
    access.token.claim: true
```

## Usage

### 1. Configure YAML File

Edit `scopes.yaml` to define your custom scopes:

```yaml
realm: customer

scopes:
  - name: user-profile
    description: User profile information
    protocol: openid-connect
    include_in_token_scope: true
    display_on_consent_screen: true
    consent_screen_text: "User profile information"
    gui_order: 1

    mappers:
      - name: email
        protocol: openid-connect
        protocol_mapper: oidc-usermodel-property-mapper
        config:
          user.attribute: email
          claim.name: email
          jsonType.label: String
          id.token.claim: true
          access.token.claim: true
          userinfo.token.claim: true
```

### 2. Set Variables

Create a `terraform.tfvars` file:

```hcl
keycloak_url          = "http://localhost:8080"
keycloak_client_id    = "admin-cli"
keycloak_username     = "admin"
keycloak_password     = "admin"
keycloak_admin_realm  = "master"
```

### 3. Initialize and Apply

```bash
cd app/scopes

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply configuration
terraform apply
```

### 4. Use Scopes in Clients

After creating scopes, you can attach them to clients:

```hcl
# In your client configuration
resource "keycloak_openid_client_default_scopes" "client_scopes" {
  realm_id  = "customer"
  client_id = keycloak_openid_client.my_client.id

  default_scopes = [
    "openid",
    "user-profile",
    "user-roles",
    "organization"
  ]
}
```

## Outputs

The module provides several useful outputs:

```bash
# View all scopes
terraform output scopes

# View scope IDs
terraform output scope_ids

# View mapper statistics
terraform output mapper_counts

# View mappers by scope
terraform output mappers_by_scope
```

## Example Scopes

The included `scopes.yaml` contains example scopes:

1. **user-profile** - Standard user claims (username, email, full name)
2. **user-roles** - Realm and client roles
3. **organization** - Organization and department information
4. **api-permissions** - API access permissions
5. **audit-info** - Audit and tracking information

## Token Claim Configuration

### Claim Types

- `id.token.claim` - Include in ID token (used for authentication)
- `access.token.claim` - Include in access token (used for authorization)
- `userinfo.token.claim` - Include in UserInfo endpoint response

### JSON Types

- `String` - String value
- `long` - Long integer
- `int` - Integer
- `boolean` - Boolean
- `JSON` - JSON object/array

### Example Token with Custom Scopes

After applying these scopes, an access token might look like:

```json
{
  "exp": 1735128000,
  "iat": 1735126200,
  "sub": "user-uuid-123",
  "preferred_username": "john.doe",
  "email": "john.doe@example.com",
  "email_verified": true,
  "name": "John Doe",
  "realm_access": {
    "roles": ["user", "admin"]
  },
  "resource_access": {
    "my-app": {
      "roles": ["app-user"]
    }
  },
  "org_id": "org-123",
  "department": "Engineering",
  "tenant": "default-tenant",
  "aud": "api-backend",
  "permissions": ["read:users", "write:users"],
  "sid": "session-abc-123"
}
```

## Best Practices

1. **Separate concerns** - Create different scopes for different types of claims
2. **Minimize ID tokens** - Only include essential identity claims in ID tokens
3. **Use consent screens** - Show consent for sensitive scopes
4. **Group related mappers** - Keep related claims in the same scope
5. **Document purposes** - Use clear descriptions for each scope
6. **Version control** - Track changes to scopes.yaml in Git

## Troubleshooting

### Invalid mapper configuration

If you get errors about invalid mapper configurations, ensure:
- Config keys use dots (e.g., `claim.name`, not `claim_name`)
- All required config keys are present
- Boolean values are `true`/`false`, not strings

### Scopes not appearing in tokens

Check that:
- Scopes are attached to the client (default or optional scopes)
- `include_in_token_scope` is `true`
- User has requested the scope (in authorization request)
- Mapper has appropriate `*.token.claim` settings

### Common Config Keys

| Mapper Type | Required Keys | Optional Keys |
|------------|---------------|---------------|
| user-property | `user.attribute`, `claim.name` | `jsonType.label` |
| user-attribute | `user.attribute`, `claim.name` | `jsonType.label` |
| hardcoded-claim | `claim.name`, `claim.value` | `jsonType.label` |
| realm-role | `claim.name` | `multivalued` |
| client-role | `claim.name` | `multivalued` |
| audience | `included.custom.audience` | - |

## Integration with M2M Module

To use these scopes with M2M clients from the `../m2m` module:

1. Apply the scopes module first:
```bash
cd app/scopes
terraform apply
```

2. Reference scope IDs in M2M module:
```bash
cd app/m2m
terraform apply
```

3. Attach scopes to M2M clients programmatically or via Keycloak admin UI

## References

- [Keycloak Client Scopes Documentation](https://www.keycloak.org/docs/latest/server_admin/#_client_scopes)
- [Terraform Keycloak Provider](https://registry.terraform.io/providers/keycloak/keycloak/latest/docs)
- [OpenID Connect Core Specification](https://openid.net/specs/openid-connect-core-1_0.html)
