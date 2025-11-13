# Configuration Resources

This directory contains Terraform configurations for Keycloak realms and identity providers.

## 📁 Structure

```
config/
├── realm/                    # Realm configurations
│   ├── customer/            # Customer realm
│   ├── sp-customer/         # SP-Customer realm (Service Provider)
│   └── idp-customer/        # IdP-Customer realm (Identity Provider)
│
└── idp-provider/            # Identity Provider configurations
    └── sp-customer/         # IdP config for SP-Customer realm
        ├── idpprovider.yml  # YAML: IdP configuration
        └── main.tf          # Terraform: Create IdP
```

## 🎯 Purpose

### Realm Configuration (`realm/`)

Creates and configures Keycloak realms with:
- Login settings (email login, registration, password reset)
- Session timeouts
- Token lifespans
- Security defenses (brute force protection, security headers)
- Password policies
- Internationalization

### Identity Provider Configuration (`idp-provider/`)

Configures identity federation between realms:
- OIDC identity providers
- PKCE support for public clients
- Attribute mappers (email, firstName, lastName, username)
- Sync modes (IMPORT, FORCE, LEGACY)
- Trust settings

## 🚀 Deployment Order

Deploy in this order:

### 1. Deploy Realms First
```bash
# Customer realm
cd realm/customer
terraform init && terraform apply -auto-approve

# SP-Customer realm
cd ../sp-customer
terraform init && terraform apply -auto-approve

# IdP-Customer realm
cd ../idp-customer
terraform init && terraform apply -auto-approve
```

### 2. Deploy Identity Providers (After Broker Clients)
```bash
# First deploy the broker client in app/idp-customer/pkce/
# Then deploy the IdP configuration

cd idp-provider/sp-customer
terraform init && terraform apply -auto-approve
```

## ⚙️ Configuration

### Realm Settings

Edit `terraform.tfvars` in each realm directory:

```hcl
realm_name         = "sp-customer"
realm_display_name = "SP Customer Portal"

# Login settings
login_with_email_allowed = true
registration_allowed     = false

# Token settings
access_token_lifespan      = 300    # 5 minutes
sso_session_idle_timeout   = 1800   # 30 minutes
sso_session_max_lifespan   = 36000  # 10 hours
```

### Identity Provider Settings

Edit `idpprovider.yml`:

```yaml
realm: sp-customer

providers:
  - alias: idp-customer-oidc
    display_name: "IdP Customer Authentication"
    enabled: true
    provider_type: oidc
    
    oidc:
      client_id: "REPLACE_WITH_UUID"  # From app/idp-customer/pkce output
      pkce_enabled: true              # No client_secret needed!
      
      issuer: "http://localhost:8080/realms/idp-customer"
      authorization_url: "http://localhost:8080/realms/idp-customer/protocol/openid-connect/auth"
      token_url: "http://localhost:8080/realms/idp-customer/protocol/openid-connect/token"
      
    settings:
      trust_email: true
      sync_mode: "FORCE"  # Always sync from IdP
```

## 🔍 Verification

### Check Realm Status
```bash
cd realm/customer
terraform output realm_info
```

### Check IdP Configuration
```bash
cd idp-provider/sp-customer
terraform output provider_details
terraform output configured_providers
```

### Test in Keycloak Console
1. Login: http://localhost:8080/admin
2. Switch realms using dropdown
3. Verify realm settings
4. Check Identity Providers (in SP-Customer)

## 📝 Common Tasks

### Update Realm Settings
1. Edit `terraform.tfvars`
2. Run `terraform apply`

### Add Another Identity Provider
1. Edit `idpprovider.yml`
2. Add new provider block (Google, GitHub, Azure AD, etc.)
3. Run `terraform apply`

### Change Token Lifespans
```hcl
# In terraform.tfvars
access_token_lifespan = 600  # Change to 10 minutes
```

Then: `terraform apply`

## 🔒 Security Notes

- **PKCE Enabled**: Public clients don't need client secrets
- **Signature Validation**: Always validate JWT signatures
- **Trust Email**: Set to `true` only for trusted IdPs
- **Sync Mode FORCE**: User data always synced from IdP on login
- **Short Token Lifespans**: Access tokens expire quickly (5 min default)

## 🔗 Related

- **Users**: See `users/` directory for user management
- **Clients**: See `app/` directory for client configurations
- **Main README**: See root `README.md` for complete flow

---

See root README.md for complete architecture and flow details.
