# Architecture Overview - Custom Client Scopes Module

## Module Structure

```
app/scopes/
│
├── scopes.yaml                 # YAML configuration (INPUT)
│   ├── realm                   # Target Keycloak realm
│   └── scopes[]                # Array of scope definitions
│       ├── name                # Scope identifier
│       ├── description         # Human-readable description
│       ├── protocol            # openid-connect
│       ├── settings            # Scope behavior settings
│       └── mappers[]           # Protocol mappers (claims)
│
├── main.tf                     # Terraform resources
│   ├── locals                  # Data transformation
│   │   ├── config              # Parsed YAML
│   │   ├── scopes              # Scopes as map
│   │   └── mappers_map         # Flattened mappers
│   │
│   └── resources               # Keycloak resources
│       ├── client_scope        # Base scope resource
│       └── protocol_mappers    # Claim mappers (8 types)
│
├── variables.tf                # Input variables
│   └── keycloak_*             # Provider credentials
│
└── outputs.tf                  # Module outputs (OUTPUT)
    ├── scopes                  # Scope details
    ├── scope_ids               # ID mappings
    └── mapper_counts           # Statistics
```

## Data Flow

```
┌─────────────────┐
│  scopes.yaml    │  User edits YAML configuration
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  yamldecode()   │  Terraform parses YAML
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  locals {}      │  Transform data structures
│  - scopes       │  - Convert arrays to maps
│  - mappers_map  │  - Flatten nested structures
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────┐
│  Resources (for_each over transformed data) │
│  ┌─────────────────────────────────┐       │
│  │ keycloak_openid_client_scope    │       │
│  └─────────────────────────────────┘       │
│  ┌─────────────────────────────────┐       │
│  │ Protocol Mappers (8 types)      │       │
│  │ - user_property                 │       │
│  │ - user_attribute                │       │
│  │ - full_name                     │       │
│  │ - hardcoded_claim               │       │
│  │ - realm_roles                   │       │
│  │ - client_roles                  │       │
│  │ - audience                      │       │
│  │ - session_note                  │       │
│  └─────────────────────────────────┘       │
└────────┬────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  Keycloak API   │  Resources created in Keycloak
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  outputs {}     │  Expose scope IDs and metadata
└─────────────────┘
```

## Mapper Type Resolution

The module uses conditional `for_each` to route mappers to the correct resource type:

```hcl
# Example: User Property Mapper routing
resource "keycloak_openid_user_property_protocol_mapper" "user_property" {
  for_each = {
    for k, v in local.mappers_map : k => v
    if v.mapper.protocol_mapper == "oidc-usermodel-property-mapper"
    #  ▲ Condition filters mappers by type
  }
  # ... mapper configuration
}
```

**Supported Mapper Types:**

| YAML `protocol_mapper` | Terraform Resource |
|----------------------|-------------------|
| `oidc-usermodel-property-mapper` | `keycloak_openid_user_property_protocol_mapper` |
| `oidc-usermodel-attribute-mapper` | `keycloak_openid_user_attribute_protocol_mapper` |
| `oidc-full-name-mapper` | `keycloak_openid_full_name_protocol_mapper` |
| `oidc-hardcoded-claim-mapper` | `keycloak_openid_hardcoded_claim_protocol_mapper` |
| `oidc-usermodel-realm-role-mapper` | `keycloak_openid_user_realm_role_protocol_mapper` |
| `oidc-usermodel-client-role-mapper` | `keycloak_openid_user_client_role_protocol_mapper` |
| `oidc-audience-mapper` | `keycloak_openid_audience_protocol_mapper` |
| `oidc-usersessionmodel-note-mapper` | `keycloak_openid_user_session_note_protocol_mapper` |

## Integration with Keycloak

```
┌───────────────────────────────────────────────────────┐
│                   Keycloak Realm                      │
│                                                       │
│  ┌─────────────────┐                                 │
│  │  Client Scopes  │◄── Created by this module       │
│  │  ├─ user-profile│                                 │
│  │  ├─ user-roles  │                                 │
│  │  ├─ organization│                                 │
│  │  ├─ api-perms   │                                 │
│  │  └─ audit-info  │                                 │
│  └────────┬────────┘                                 │
│           │                                           │
│           │ Attached to                               │
│           ▼                                           │
│  ┌─────────────────┐                                 │
│  │  OIDC Clients   │◄── Created by M2M module        │
│  │  ├─ api-gateway │                                 │
│  │  ├─ backend-svc │                                 │
│  │  └─ microservice│                                 │
│  └────────┬────────┘                                 │
│           │                                           │
│           │ Used in                                   │
│           ▼                                           │
│  ┌─────────────────┐                                 │
│  │  Access Tokens  │                                 │
│  │  {               │                                 │
│  │    "sub": "..." │                                 │
│  │    "email": "..."│ ◄── Claims from scopes         │
│  │    "roles": [...│                                 │
│  │    "org_id": "..."                                │
│  │  }               │                                 │
│  └─────────────────┘                                 │
└───────────────────────────────────────────────────────┘
```

## Token Generation Flow

```
┌──────────┐
│   User   │ Authenticates
└────┬─────┘
     │
     ▼
┌──────────────────────┐
│  Authorization       │ Requests scopes:
│  Request             │ scope=openid user-profile organization
└────┬─────────────────┘
     │
     ▼
┌──────────────────────┐
│  Keycloak            │
│  1. Authenticates user
│  2. Resolves scopes   │ ◄── Looks up custom scopes
│  3. Applies mappers   │ ◄── Executes protocol mappers
│  4. Generates token   │
└────┬─────────────────┘
     │
     ▼
┌──────────────────────┐
│  Access Token        │
│  {                   │
│    "sub": "user-123" │ ◄── From authentication
│    "email": "..."    │ ◄── From user-profile scope
│    "org_id": "..."   │ ◄── From organization scope
│  }                   │
└──────────────────────┘
```

## YAML to Terraform Mapping

### Example: Single Scope with Mapper

**YAML Input:**
```yaml
scopes:
  - name: user-profile
    description: User profile information
    include_in_token_scope: true

    mappers:
      - name: email
        protocol_mapper: oidc-usermodel-property-mapper
        config:
          user.attribute: email
          claim.name: email
```

**Terraform Resources Created:**
```hcl
# 1. Scope resource
resource "keycloak_openid_client_scope" "scope" {
  for_each = { "user-profile" = {...} }

  realm_id               = "customer"
  name                   = "user-profile"
  description            = "User profile information"
  include_in_token_scope = true
}

# 2. Mapper resource
resource "keycloak_openid_user_property_protocol_mapper" "user_property" {
  for_each = { "user-profile-email" = {...} }

  realm_id        = "customer"
  client_scope_id = keycloak_openid_client_scope.scope["user-profile"].id
  name            = "email"
  claim_name      = "email"
  user_property   = "email"
}
```

## Locals Transformation Logic

### Step 1: Parse YAML
```hcl
config = yamldecode(file("scopes.yaml"))
# Result:
# {
#   realm = "customer"
#   scopes = [
#     { name = "user-profile", mappers = [...] }
#   ]
# }
```

### Step 2: Convert to Map
```hcl
scopes = { for scope in config.scopes : scope.name => scope }
# Result:
# {
#   "user-profile" = { name = "user-profile", mappers = [...] }
# }
```

### Step 3: Flatten Mappers
```hcl
scope_mappers = flatten([
  for scope_name, scope in scopes : [
    for mapper in scope.mappers : {
      scope_name  = scope_name
      mapper_name = mapper.name
      unique_key  = "${scope_name}-${mapper.name}"
    }
  ]
])
# Result: Array of mapper objects with unique keys
```

### Step 4: Create Mapper Map
```hcl
mappers_map = { for mapper in scope_mappers : mapper.unique_key => mapper }
# Result:
# {
#   "user-profile-email" = { scope_name = "user-profile", ... }
# }
```

## Dependency Graph

```
scopes.yaml
    │
    ▼
locals.config (yamldecode)
    │
    ├──► locals.scopes (for_each map)
    │       │
    │       ▼
    │    keycloak_openid_client_scope.scope
    │       │
    │       ▼ (dependency)
    │
    └──► locals.scope_mappers (flatten)
            │
            ▼
         locals.mappers_map
            │
            ├──► user_property_mapper ──┐
            ├──► user_attribute_mapper ─┤
            ├──► full_name_mapper ──────┤
            ├──► hardcoded_mapper ──────┤
            ├──► realm_roles_mapper ────┤ ──► All depend on client_scope
            ├──► client_roles_mapper ───┤
            ├──► audience_mapper ────────┤
            └──► session_note_mapper ───┘
```

## Resource Lifecycle

```
terraform apply
    │
    ├──► Create scopes first
    │    (keycloak_openid_client_scope)
    │
    └──► Create mappers in parallel
         (all mapper types can be created simultaneously
          once scopes exist)

terraform destroy
    │
    ├──► Delete mappers first
    │    (cannot delete scope while mappers exist)
    │
    └──► Delete scopes
```

## State Management

```
terraform.tfstate
{
  "resources": [
    {
      "type": "keycloak_openid_client_scope",
      "name": "scope",
      "instances": [
        { "index_key": "user-profile", "attributes": {...} },
        { "index_key": "user-roles", "attributes": {...} }
      ]
    },
    {
      "type": "keycloak_openid_user_property_protocol_mapper",
      "name": "user_property",
      "instances": [
        { "index_key": "user-profile-email", "attributes": {...} }
      ]
    }
  ]
}
```

## Security Considerations

### 1. Sensitive Data in Tokens
- ❌ Don't include passwords, secrets, or PII in hardcoded claims
- ✅ Use user attributes that are already secured in Keycloak

### 2. Token Size
- ❌ Avoid adding too many claims (JWT size limit ~8KB)
- ✅ Keep claims minimal and relevant

### 3. Claim Visibility
- ❌ Don't put sensitive claims in ID tokens (visible to frontend)
- ✅ Use access tokens for sensitive claims (backend only)

### 4. Consent Screens
- ✅ Show consent for sensitive scopes (`display_on_consent_screen: true`)
- ✅ Use clear, user-friendly `consent_screen_text`

## Performance Considerations

### Terraform Plan/Apply Time
- **Small deployments** (5 scopes, 20 mappers): ~10 seconds
- **Medium deployments** (20 scopes, 100 mappers): ~30 seconds
- **Large deployments** (50 scopes, 300 mappers): ~90 seconds

### Optimization Tips
1. Use `terraform apply -target` for incremental changes
2. Group related mappers in the same scope
3. Avoid unnecessary mappers (each mapper = API call)

## Extension Points

### Adding New Mapper Types

1. **Add to YAML**: Define mapper with new `protocol_mapper` type
2. **Add Resource**: Create new Terraform resource block
3. **Add Filter**: Use `for_each` with appropriate condition
4. **Document**: Update README with new mapper type

Example:
```hcl
resource "keycloak_openid_group_membership_protocol_mapper" "group_mapper" {
  for_each = {
    for k, v in local.mappers_map : k => v
    if v.mapper.protocol_mapper == "oidc-group-membership-mapper"
  }
  # ... configuration
}
```

## Comparison with Manual Configuration

| Aspect | Manual (Keycloak UI) | This Module |
|--------|---------------------|-------------|
| Configuration | Click-based, per realm | YAML-based, multi-realm |
| Version Control | No | Yes (Git) |
| Repeatability | Manual steps | Automated |
| Documentation | External docs | Self-documenting YAML |
| Collaboration | Screen sharing | Code review |
| Disaster Recovery | Manual backup | `terraform apply` |
| Multi-Environment | Manual duplication | Same YAML, different vars |

## Future Enhancements

### Potential Additions
1. **Scope templates** - Pre-built scope configurations
2. **Validation** - YAML schema validation
3. **Dynamic claims** - Runtime claim resolution
4. **Scope dependencies** - Automatic scope inclusion
5. **Testing** - Automated token claim verification
