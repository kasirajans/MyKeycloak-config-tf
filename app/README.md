# Application Clients Configuration

This directory contains Terraform modules for managing OAuth 2.0 / OIDC clients in Keycloak.

## 📁 Module Structure

```
app/
├── scopes/              # Custom client scopes and protocol mappers
├── aiAgent/             # Standardized AI agent clients (opinionated M2M)
├── m2m/                 # Machine-to-machine clients (flexible)
├── pkce/                # PKCE clients (public) for web/mobile apps
├── password-grant/      # Password grant clients (legacy/deprecated)
└── README.md            # This file (overview)
```

**Each module has its own detailed README:**
- [scopes/README.md](scopes/README.md) - Client scopes and protocol mappers
- [aiAgent/README.md](aiAgent/README.md) - Standardized AI agent clients
- [m2m/README.md](m2m/README.md) - Flexible M2M/service account clients
- [pkce/README.md](pkce/README.md) - PKCE clients for web/mobile
- [password-grant/README.md](password-grant/README.md) - Password grant (deprecated)

## 🎯 Quick Module Selection

### Choose Your Client Type

| I need... | Use Module | Documentation |
|-----------|-----------|---------------|
| **AI agent** with standardized config | `aiAgent/` | [AIAgent README](aiAgent/README.md) |
| **Web/Mobile app** (React, Angular, mobile) | `pkce/` | [PKCE README](pkce/README.md) |
| **Service-to-service** auth (flexible config) | `m2m/` | [M2M README](m2m/README.md) |
| **Custom scopes/claims** for clients | `scopes/` | [Scopes README](scopes/README.md) |
| **Legacy app** (not recommended) | `password-grant/` | [Password Grant README](password-grant/README.md) |

## 🚀 Common Workflows

### Workflow 1: Web Application with MFA

For a React/Angular/Vue application with multi-factor authentication:

1. **Deploy MFA flow** (optional):
   ```bash
   cd ../config/Authentication/flow/MFA
   terraform apply -auto-approve
   ```

2. **Deploy PKCE client**:
   ```bash
   cd ../../../app/pkce
   terraform apply -auto-approve
   terraform output -json pkce_clients | jq '.["my-app"]'
   ```

3. **Implement in your app** - See [pkce/README.md](pkce/README.md#-pkce-flow)

### Workflow 2: Service Account (M2M) with Custom Scopes

For backend services that need custom claims/scopes:

1. **Deploy custom scopes**:
   ```bash
   cd scopes
   terraform apply -auto-approve
   ```

2. **Deploy M2M client**:
   ```bash
   cd ../m2m
   terraform apply -auto-approve
   ```

3. **Get credentials**:
   ```bash
   CLIENT_ID=$(terraform output -json m2m_clients | jq -r '.["my-service"].client_id')
   CLIENT_SECRET=$(terraform output -json m2m_client_secrets | jq -r '.["my-service"]')
   ```

4. **Get tokens** - See [m2m/README.md](m2m/README.md#-getting-access-tokens)

### Workflow 3: Realm Federation (Broker)

For SP realm federating to IdP realm:

1. **Deploy broker client in IdP**:
   ```bash
   cd pkce  # Broker uses PKCE
   # Edit apps.yaml with broker configuration
   terraform apply -auto-approve
   terraform output -json pkce_clients | jq -r '.["sp-broker"].client_id'
   ```

2. **Configure IdP in SP** - See identity provider configuration docs

## 📖 Module Documentation

For detailed information about each module, see their individual READMEs:

### [Scopes Module](scopes/README.md)
- Custom client scopes and protocol mappers
- Supported mapper types (audience, hardcoded claims, user attributes, etc.)
- Scope configuration examples
- **Start here** if you need custom claims in tokens

### [AIAgent Module](aiAgent/README.md)
- Standardized M2M clients for AI agents
- Enforced naming: `aiagent_<AppName>`
- Structured metadata: `<Owner>;<Team>;<Email>`
- Hardcoded security settings (30-min tokens, Client Credentials only)
- Minimal YAML configuration (4 fields only)
- **Start here** for AI agent service accounts

### [M2M Module](m2m/README.md)
- Flexible machine-to-machine clients
- Client Credentials grant flow
- Customizable token lifespans, scopes, and settings
- Auto-generated secure secrets (48 chars)
- **Start here** for general backend service authentication

### [PKCE Module](pkce/README.md)
- Public clients for web/mobile applications
- Authorization Code + PKCE flow
- Multi-factor authentication (MFA) support
- CORS configuration
- Protocol mappers (user attributes, audience)
- **Start here** for frontend applications

### [Password Grant Module](password-grant/README.md)
- Legacy password grant flow (deprecated)
- Migration guide to PKCE or M2M
- **Avoid for new applications**

## 🔍 Quick Reference

### Terraform Outputs

Each module has its own outputs:

```bash
# PKCE clients
cd pkce && terraform output pkce_clients

# AIAgent clients
cd aiAgent && terraform output aiagent_summary           # Non-sensitive
cd aiAgent && terraform output aiagent_clients           # Sensitive
cd aiAgent && terraform output aiagent_client_secrets    # Sensitive

# M2M clients
cd m2m && terraform output m2m_clients
cd m2m && terraform output m2m_client_secrets  # Sensitive

# Scopes
cd scopes && terraform output scopes

# Password grant clients
cd password-grant && terraform output password_grant_clients
```

**See each module's README for detailed output examples and usage.**

## 🔑 Client Type Comparison

| Feature | PKCE | M2M | Password Grant |
|---------|------|-----|----------------|
| **Access Type** | PUBLIC | CONFIDENTIAL | PUBLIC or CONFIDENTIAL |
| **OAuth Flow** | Authorization Code + PKCE | Client Credentials | Resource Owner Password |
| **Client Secret** | ❌ No | ✅ Yes (48-char) | Optional |
| **Use Case** | Web/mobile apps | Service-to-service | Legacy apps |
| **Security** | ✅ High | ✅ High | ❌ Low (deprecated) |
| **MFA Support** | ✅ Yes | ❌ N/A | ❌ Difficult |
| **User Context** | ✅ Yes | ❌ No | ✅ Yes |
| **Recommended** | ✅ Yes | ✅ Yes | ❌ No |

**Detailed information:** See each module's README for OAuth flows, security considerations, and implementation examples.

## 🛠️ Common Issues

### "Output 'clients' not found"

Each module has its own output names:
- `pkce_clients` (not `clients`)
- `m2m_clients` (not `clients`)
- `scopes` (not `client_scopes`)

### "Scope not found"

Deploy scopes before clients:
```bash
cd scopes && terraform apply
cd ../m2m && terraform apply  # Now can reference scopes
```

### "Invalid redirect_uri" / CORS errors

See [pkce/README.md](pkce/README.md#-troubleshooting) for PKCE-specific issues.

### Module-Specific Troubleshooting

Each module has detailed troubleshooting:
- [scopes/README.md - Troubleshooting](scopes/README.md#-troubleshooting)
- [m2m/README.md - Troubleshooting](m2m/README.md#-troubleshooting)
- [pkce/README.md - Troubleshooting](pkce/README.md#-troubleshooting)
- [password-grant/README.md - Troubleshooting](password-grant/README.md#-troubleshooting)

## 🔗 Related

- **Identity Providers**: See `config/idp-provider/` for federation setup
- **Users**: See `users/` for user management
- **Main README**: See root `README.md` for complete flow

---

See root README.md for complete architecture and deployment order.
