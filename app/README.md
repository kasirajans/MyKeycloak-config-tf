# Application Clients Configuration

This directory contains Terraform configurations for OIDC clients (applications) in all realms.

## 📁 Structure

```
app/
├── customer/                 # Customer realm clients
│   ├── pkce/                # PKCE clients (public)
│   ├── m2m/                 # Machine-to-machine (confidential)
│   └── password-grant/      # Password grant clients
│
├── sp-customer/             # SP-Customer realm clients
│   └── pkce/                # PKCE clients with broker
│       ├── apps.yaml        # YAML: Client configuration
│       └── main.tf          # Terraform: Create clients
│
└── idp-customer/            # IdP-Customer realm clients
    └── pkce/                # PKCE broker clients
        ├── apps.yaml        # YAML: Broker client config
        └── main.tf          # Terraform: Create broker
```

## 🎯 Purpose

Creates OIDC clients (applications) in Keycloak realms:
- **PKCE Clients**: Public clients for web/mobile apps (no client secret)
- **M2M Clients**: Service-to-service authentication (confidential)
- **Broker Clients**: Clients used by SP realms to federate authentication

## 🚀 Quick Start

### Deploy IdP-Customer Broker Client

```bash
cd idp-customer/pkce
terraform init
terraform apply -auto-approve

# Get the client UUID (needed for IdP configuration)
terraform output -json clients | jq -r '.["sp-customer-broker-pkce"].client_id'
```

### Deploy SP-Customer PKCE Client

```bash
cd sp-customer/pkce
terraform init
terraform apply -auto-approve

# Get client UUID for your application
terraform output clients
```

## ⚙️ YAML Configuration

### PKCE Client Example

```yaml
# File: apps.yaml
realm: sp-customer

clients:
  - client_id: mobile-web-app-broker
    name: "Mobile/Web App Broker Client"
    enabled: true
    
    pkce:
      challenge_method: S256  # SHA-256
    
    redirect_uris:
      - http://localhost:5173/callback
      - http://localhost:3000/callback
    
    web_origins:
      - http://localhost:5173
      - http://localhost:3000
    
    token_settings:
      access_token_lifespan: 300      # 5 minutes
      session_idle_timeout: 1800      # 30 minutes
      session_max_lifespan: 36000     # 10 hours
    
    consent_required: false
    
    # Protocol Mappers
    mappers:
      - type: user_attribute
        name: email
        user_attribute: email
        claim_name: email
      
      - type: user_attribute
        name: firstName
        user_attribute: firstName
        claim_name: given_name
      
      - type: audience
        name: audience
        audience: self  # Use client's own UUID
```

## 📝 Adding Clients

### Add a New PKCE Client

1. Edit `apps.yaml`:
```yaml
clients:
  - client_id: my-new-app
    name: "My New Application"
    enabled: true
    pkce:
      challenge_method: S256
    redirect_uris:
      - http://localhost:4200/callback
    web_origins:
      - http://localhost:4200
    token_settings:
      access_token_lifespan: 300
      session_idle_timeout: 1800
      session_max_lifespan: 36000
    consent_required: false
    mappers:
      - type: audience
        name: audience
        audience: self
```

2. Apply changes:
```bash
terraform apply
```

3. Get client UUID:
```bash
terraform output -json clients | jq -r '.["my-new-app"].client_id'
```

## 🔍 Viewing Configuration

### Get All Clients
```bash
terraform output clients
```

### Get Specific Client UUID
```bash
terraform output -json clients | jq -r '.["client-id"].client_id'
```

### Get OIDC Endpoints
```bash
terraform output endpoints
```

### Get Configuration Summary
```bash
terraform output configuration_summary
```

## 🔑 Client Types

### PKCE Clients (PUBLIC)
- **Access Type**: PUBLIC
- **Use Case**: Web apps, SPAs, mobile apps
- **Client Secret**: ❌ Not needed
- **PKCE**: ✅ Required
- **Example**: React app, Angular app, mobile app

### M2M Clients (CONFIDENTIAL)
- **Access Type**: CONFIDENTIAL
- **Use Case**: Service-to-service communication
- **Client Secret**: ✅ Required
- **PKCE**: ❌ Not used
- **Example**: Backend service calling API

### Broker Clients (PKCE)
- **Access Type**: PUBLIC
- **Use Case**: SP realm federating to IdP realm
- **Client Secret**: ❌ Not needed
- **PKCE**: ✅ Required
- **Example**: SP-Customer → IdP-Customer

## 🔒 Security

### PKCE Flow
```
1. App generates code_verifier (random string)
2. App generates code_challenge = SHA256(code_verifier)
3. App sends code_challenge in auth request
4. IdP stores code_challenge
5. User authenticates
6. App receives authorization code
7. App sends code + code_verifier to token endpoint
8. IdP verifies: SHA256(code_verifier) == code_challenge
9. IdP issues tokens
```

### Token Settings
- **Access Token**: 5 minutes (short-lived)
- **Session Idle**: 30 minutes (user inactivity)
- **Session Max**: 10 hours (absolute maximum)

## 📊 Protocol Mappers

### User Attribute Mapper
Maps user attributes to JWT claims:
```yaml
- type: user_attribute
  name: email
  user_attribute: email      # Source from user profile
  claim_name: email          # Target claim in JWT
```

### Audience Mapper
Adds audience claim to token:
```yaml
- type: audience
  name: audience
  audience: self  # Use "self" for client's own UUID
```

Result in JWT:
```json
{
  "aud": "501c3036-83aa-96f9-efd9-94d853f2be8e",
  "email": "john.doe@idp-customer.com",
  "given_name": "John",
  "family_name": "Doe"
}
```

## 🛠️ Troubleshooting

### "Invalid redirect_uri"
**Solution**: Add the URI to `redirect_uris` in apps.yaml

### "Missing code_challenge_method"
**Solution**: Ensure PKCE is enabled with `challenge_method: S256`

### "Invalid client"
**Solution**: Verify client UUID is correct in your app configuration

### "Client not found"
**Solution**: Check you deployed the client with `terraform apply`

## 🔗 Related

- **Identity Providers**: See `config/idp-provider/` for federation setup
- **Users**: See `users/` for user management
- **Main README**: See root `README.md` for complete flow

---

See root README.md for complete architecture and deployment order.
