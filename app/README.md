# Application Clients Configuration

This directory contains Terraform configurations for OIDC clients (applications) in all realms.

## 📁 Structure

```
app/
├── pkce/                # PKCE clients (public)
├── m2m/                 # Machine-to-machine (confidential)
└── password-grant/      # Password grant clients

```

## 🎯 Purpose

Creates OIDC clients (applications) in Keycloak realms:
- **PKCE Clients**: Public clients for web/mobile apps (no client secret)
- **M2M Clients**: Service-to-service authentication (confidential)
- **Broker Clients**: Clients used by SP realms to federate authentication

## 🚀 Quick Start

### Deploy MFA Authentication Flow

```bash
cd ../config/Authentication/flow/MFA
terraform init
terraform apply -auto-approve

# This creates the mfa-browser flow with username/password + WebAuthn
```

### Deploy IdP-Customer Broker Client with MFA

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

### PKCE Client Example with MFA

```yaml
# File: apps.yaml
realm: idp-customer

clients:
  - client_id: sp-customer-broker-pkce
    name: "SP Customer Broker (PKCE)"
    enabled: true
    
    # Authentication Flow Configuration for MFA
    authentication_flow:
      browser_flow: mfa-browser  # Uses username/password + WebAuthn
    
    pkce:
      challenge_method: S256  # SHA-256
    
    redirect_uris:
      - http://localhost:8080/realms/sp-customer/broker/idp-customer-oidc/endpoint/*
      - http://localhost:5173/callback
    
    web_origins:
      - http://localhost:8080
      - http://localhost:5173  # Frontend app for CORS
    
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
      
      - type: user_attribute
        name: lastName
        user_attribute: lastName
        claim_name: family_name
      
      - type: user_attribute
        name: username
        user_attribute: username
        claim_name: preferred_username
      
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

### MFA + PKCE Flow
```
1. App generates code_verifier (random string)
2. App generates code_challenge = SHA256(code_verifier)
3. App sends code_challenge in auth request
4. IdP stores code_challenge
5. User enters username/password (first factor)
6. User completes WebAuthn authentication (second factor)
7. App receives authorization code
8. App sends code + code_verifier to token endpoint
9. IdP verifies: SHA256(code_verifier) == code_challenge
10. IdP issues tokens
```

### Multi-Factor Authentication (MFA)
- **First Factor**: Username/Password (`auth-username-password-form`)
- **Second Factor**: WebAuthn (`webauthn-authenticator`)
- **Supported Devices**: Fingerprint, Face ID, Security Keys (YubiKey), Windows Hello
- **Flow**: Custom `mfa-browser` flow enforces both factors

### CORS Configuration
Custom headers allowed for development:
- Standard headers: `Accept`, `Authorization`, `Content-Type`, etc.
- Custom header: `ngrok-skip-browser-warning` (for ngrok development)

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

### Authentication Issues

#### "Invalid redirect_uri"
**Solution**: Add the URI to `redirect_uris` in apps.yaml

#### "Missing code_challenge_method"
**Solution**: Ensure PKCE is enabled with `challenge_method: S256`

#### "Invalid client"
**Solution**: Verify client UUID is correct in your app configuration

#### "Client not found"
**Solution**: Check you deployed the client with `terraform apply`

### MFA Issues

#### Users don't see WebAuthn prompt
**Solution**: Ensure users have registered WebAuthn credentials in Account Console

#### "Security > Passwordless" not visible
**Solution**: 
1. Check Keycloak version (19+ required)
2. Verify `webauthn-register` required action is enabled
3. Use default Keycloak theme for testing

#### MFA flow not triggering
**Solution**: 
1. Verify `mfa-browser` flow exists: `data.keycloak_authentication_flow.mfa_browser`
2. Check client has `authentication_flow.browser_flow: mfa-browser` in YAML
3. Ensure MFA flow is deployed before client

### CORS Issues

#### "Access-Control-Allow-Origin" error
**Solution**: Add frontend URL to `web_origins` in apps.yaml

#### "Request header field X not allowed"
**Solution**: Custom headers are configured in `extra_config.cors.allowed.headers`

#### CORS with ngrok development
**Solution**: `ngrok-skip-browser-warning` header is pre-configured

## 🔗 Related

- **Identity Providers**: See `config/idp-provider/` for federation setup
- **Users**: See `users/` for user management
- **Main README**: See root `README.md` for complete flow

---

See root README.md for complete architecture and deployment order.
