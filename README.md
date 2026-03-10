# Keycloak SSO Infrastructure as Code

Complete Keycloak SSO setup using Terraform with multi-realm identity federation, PKCE authentication, and YAML-based configuration.

## 🎯 Overview

This project implements a complete identity and access management (IAM) infrastructure using Keycloak with:

- **Multi-Realm Architecture**: Three realms (customer, sp-customer, idp-customer)
- **Identity Federation**: SP-Customer realm federates authentication to IdP-Customer realm
- **PKCE Support**: Secure authentication for public clients (web/mobile apps)
- **YAML Configuration**: No code changes needed - just edit YAML files
- **Infrastructure as Code**: Everything managed with Terraform

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Customer Realm                               │
│                    (Main Application Realm)                         │
│                                                                     │
│  ├── PKCE Clients (Public)         - Web/Mobile apps               │
│  ├── M2M Clients (Confidential)    - Service-to-service            │
│  └── Password Grant Clients        - Legacy applications           │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                      SP-Customer Realm                              │
│                    (Service Provider)                               │
│                                                                     │
│  ├── PKCE Clients (Public)         - Apps with broker auth         │
│  └── Identity Provider             - Federates to IdP-Customer     │
│       └── idp-customer-oidc                                         │
│           ├── PKCE Enabled: Yes                                     │
│           └── Client: sp-customer-broker-pkce                       │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                │ OIDC Federation (PKCE)
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    IdP-Customer Realm                               │
│                  (Identity Provider / Authorization Server)         │
│                                                                     │
│  ├── Broker Clients (PKCE)         - For SP realms                 │
│  │   └── sp-customer-broker-pkce   - PUBLIC client (no secret)     │
│  └── Users                          - john.doe@idp-customer.com     │
│      └── sarah.miller@idp-customer.com                             │
└─────────────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
SSO/
├── README.md                          # This file - Master overview
│
├── config/                            # Configuration resources
│   ├── realm/                        # Realm configurations
│   │   ├── customer/                 # Customer realm setup
│   │   ├── sp-customer/              # SP-Customer realm setup
│   │   └── idp-customer/             # IdP-Customer realm setup
│   │
│   └── idp-provider/                 # Identity Provider configs
│       └── sp-customer/              # IdP config for SP-Customer
│           ├── idpprovider.yml       # YAML: IdP configuration
│           └── main.tf               # Terraform: Create IdP
│
├── app/                              # Application/Client configs
│   ├── customer/                     # Customer realm clients
│   │   ├── pkce/                     # PKCE clients (web/mobile)
│   │   ├── m2m/                      # Machine-to-machine clients
│   │   └── password-grant/           # Password grant clients
│   │
│   ├── sp-customer/                  # SP-Customer realm clients
│   │   └── pkce/                     # PKCE clients with broker
│   │       ├── apps.yaml             # YAML: Client configuration
│   │       └── main.tf               # Terraform: Create clients
│   │
│   └── idp-customer/                 # IdP-Customer realm clients
│       └── pkce/                     # PKCE broker clients
│           ├── apps.yaml             # YAML: Broker client config
│           └── main.tf               # Terraform: Create broker
│
└── users/                            # User management
    ├── customer/                     # Customer realm users
    ├── sp-customer/                  # SP-Customer realm users
    └── idp-customer/                 # IdP-Customer realm users
        ├── user.csv                  # CSV: User data
        └── main.tf                   # Terraform: Create users
```

## 🚀 Quick Start

### Prerequisites

- **Keycloak Server**: Running at `http://localhost:9090`
- **Terraform**: v1.0 or higher
- **Admin Credentials**: admin/admin (default)

### 1. Deploy Realms

```bash
# Deploy all three realms
cd config/realm/customer && terraform init && terraform apply -auto-approve
cd ../sp-customer && terraform init && terraform apply -auto-approve
cd ../idp-customer && terraform init && terraform apply -auto-approve
```

### 2. Create Users in IdP-Customer

```bash
cd users/idp-customer
terraform init
terraform apply -auto-approve
```

Users created:
- `john.doe@idp-customer.com`
- `sarah.miller@idp-customer.com`

### 3. Deploy Broker Client in IdP-Customer

```bash
cd app/idp-customer/pkce
terraform init
terraform apply -auto-approve

# Get the client UUID
terraform output -json clients | jq -r '.["sp-customer-broker-pkce"].client_id'
```

### 4. Configure Identity Provider in SP-Customer

```bash
cd config/idp-provider/sp-customer

# The client_id should already be in idpprovider.yml
# Verify it matches the output from step 3
cat idpprovider.yml

# Deploy the IdP configuration
terraform init
terraform apply -auto-approve
```

### 5. Deploy PKCE Clients

```bash
# SP-Customer PKCE clients (with broker)
cd app/sp-customer/pkce
terraform init
terraform apply -auto-approve

# Get client UUID for your app
terraform output clients
```

### 6. Test the Flow

1. **Start your web app** at `http://localhost:5173` (or configured redirect URI)
2. **Initiate login** using the PKCE client UUID from step 5
3. **User is redirected** to SP-Customer realm
4. **Click "IdP Customer Authentication"** button
5. **Login with**: `john.doe@idp-customer.com` / `[password from terraform output]`
6. **Success!** User is authenticated via IdP-Customer

## 🔑 Key Concepts

### YAML-Based Configuration

All clients and identity providers are configured via YAML files - **no Terraform code changes needed!**

**Example: Adding a new PKCE client**
```yaml
# File: app/sp-customer/pkce/apps.yaml
clients:
  - client_id: my-new-app
    name: "My New Application"
    enabled: true
    pkce:
      challenge_method: S256
    redirect_uris:
      - http://localhost:3000/callback
    mappers:
      - type: user_attribute
        name: email
        user_attribute: email
        claim_name: email
```

Then just run: `terraform apply`

### PKCE (Proof Key for Code Exchange)

- **What**: Enhanced security for public clients (web/mobile apps)
- **Why**: No client secrets needed - uses code challenge/verifier
- **Where**: Used in IdP-Customer broker client and SP-Customer PKCE clients
- **How**: `pkce_enabled: true` in configuration

### Identity Federation Flow (Login)

```
[User's Browser]
      │
      ├─► 1. Navigate to app (localhost:5173)
      │
      ├─► 2. App initiates PKCE login to SP-Customer
      │       POST /realms/sp-customer/protocol/openid-connect/auth
      │       + client_id=<CLIENT_UUID>
      │       + redirect_uri=http://localhost:5173/callback
      │       + response_type=code
      │       + scope=openid profile email
      │       + code_challenge (PKCE - SHA256 hash)
      │       + code_challenge_method=S256
      │
      ├─► 3. SP-Customer shows login page
      │       "Login" or "IdP Customer Authentication" button
      │
      ├─► 4. User clicks "IdP Customer Authentication"
      │       (triggers broker flow to IdP-Customer)
      │
      ├─► 5. SP-Customer redirects to IdP-Customer (PKCE)
      │       GET /realms/idp-customer/protocol/openid-connect/auth
      │       + client_id=sp-customer-broker-pkce (broker client)
      │       + code_challenge (passed through)
      │       + code_challenge_method=S256
      │
      ├─► 6. User logs in to IdP-Customer
      │       Username: john.doe@idp-customer.com
      │       Password: [from terraform output]
      │
      ├─► 7. IdP-Customer validates credentials & returns auth code
      │       Redirects back to SP-Customer broker endpoint
      │       + authorization_code
      │
      ├─► 8. SP-Customer exchanges code for token (with PKCE verifier)
      │       POST /realms/idp-customer/protocol/openid-connect/token
      │       + grant_type=authorization_code
      │       + code=<authorization_code>
      │       + code_verifier (PKCE - original random string)
      │       + client_id=sp-customer-broker-pkce
      │
      ├─► 9. IdP-Customer validates code_verifier and returns tokens
      │       Returns: access_token, id_token, refresh_token
      │
      ├─► 10. SP-Customer creates/updates/links user account
      │        - First time: Creates new user with email from IdP
      │        - Subsequent: Links to existing user or updates attributes
      │        - Sync mode controls: import/force/legacy
      │
      └─► 11. SP-Customer redirects to app with SP-Customer token
              + authorization_code (for SP-Customer realm)
              
      ├─► 12. App exchanges SP code for SP-Customer tokens
              POST /realms/sp-customer/protocol/openid-connect/token
              + grant_type=authorization_code
              + code=<sp_authorization_code>
              + code_verifier (app's original PKCE verifier)
              + client_id=<APP_CLIENT_UUID>
              
      └─► 13. App receives tokens and user is authenticated!
              access_token, id_token, refresh_token (from SP-Customer)
```

### Logout Flow

```
[User's Browser - Logout Initiated]
      │
      ├─► 1. App initiates logout
      │       GET /realms/sp-customer/protocol/openid-connect/logout
      │       + id_token_hint=<user's_id_token>
      │       + post_logout_redirect_uri=http://localhost:5173
      │       + client_id=<CLIENT_UUID>
      │
      ├─► 2. SP-Customer terminates local session
      │       - Invalidates access_token
      │       - Clears SSO session cookies
      │       - Marks session as logged out
      │
      ├─► 3. SP-Customer propagates logout to IdP-Customer (backchannel)
      │       POST /realms/idp-customer/protocol/openid-connect/logout
      │       + Terminates IdP session
      │       + Clears IdP SSO cookies
      │
      ├─► 4. SP-Customer redirects to post_logout_redirect_uri
      │       User is redirected back to app
      │
      └─► 5. App clears local tokens and session
              User is fully logged out from:
              - Application
              - SP-Customer realm
              - IdP-Customer realm (via broker)
```

### Session Management

**Token Lifespans:**
- **Access Token**: 5 minutes (300s)
- **SSO Session Idle**: 30 minutes (1800s)
- **SSO Session Max**: 10 hours (36000s)
- **Offline Session Idle**: 30 days
- **Offline Session Max**: 60 days

**Single Sign-On (SSO):**
- User logs in once to IdP-Customer
- Automatically authenticated to SP-Customer (and any other federated realms)
- SSO session maintained across all federated realms
- Logout from one realm logs out from all realms (if backchannel enabled)

**Session Timeout:**
- After 30 minutes of inactivity → Token refresh required
- After 10 hours max → Must re-authenticate
- Refresh tokens can extend session without re-login (until offline max)


## 📝 Common Tasks

### Add a New Client

1. Edit the appropriate `apps.yaml` file
2. Add your client configuration
3. Run `terraform apply`

### Add a New Identity Provider

1. Edit `config/idp-provider/sp-customer/idpprovider.yml`
2. Add provider configuration (Google, GitHub, Azure AD, etc.)
3. Run `terraform apply`

### Add New Users

1. Edit `users/idp-customer/user.csv`
2. Add user rows
3. Run `terraform apply`

### Get Client Credentials

```bash
# Get all clients
cd app/sp-customer/pkce
terraform output clients

# Get specific client UUID
terraform output -json clients | jq -r '.["mobile-web-app-broker"].client_id'
```

### View User Passwords

```bash
cd users/idp-customer
terraform output user_credentials
```

## 🔒 Security Features

- ✅ **PKCE for Public Clients** - No client secrets exposed
- ✅ **Short Token Lifespans** - Access tokens expire in 5 minutes
- ✅ **Signature Validation** - JWT tokens validated via JWKS
- ✅ **Brute Force Protection** - Failed login attempt limiting
- ✅ **Security Headers** - XSS, CSRF, Clickjacking protection
- ✅ **HTTPS Ready** - Use HTTPS in production (currently localhost for dev)

## 🧪 Testing

### Test Login Flow

```bash
# Start a simple HTTP server to test callbacks
cd /tmp
python3 -m http.server 5173 &

# Open browser
open http://localhost:5173

# Manually construct PKCE login URL:
# 1. Generate code_verifier (random string, 43-128 chars)
# 2. Generate code_challenge (SHA256 hash of verifier, base64url encoded)
# 3. Navigate to:
#    http://localhost:9090/realms/sp-customer/protocol/openid-connect/auth
#    ?client_id=<CLIENT_UUID>
#    &redirect_uri=http://localhost:5173/callback
#    &response_type=code
#    &scope=openid profile email
#    &code_challenge=<CHALLENGE>
#    &code_challenge_method=S256
#    &state=<RANDOM_STATE>

# 4. Click "IdP Customer Authentication" button
# 5. Login with: john.doe@idp-customer.com / [password from terraform output]
# 6. Exchange authorization code for tokens
#    POST http://localhost:9090/realms/sp-customer/protocol/openid-connect/token
#    grant_type=authorization_code
#    code=<AUTH_CODE>
#    redirect_uri=http://localhost:5173/callback
#    client_id=<CLIENT_UUID>
#    code_verifier=<ORIGINAL_VERIFIER>
```

### Test Logout Flow

```bash
# After successful login, initiate logout:
# Navigate to:
http://localhost:9090/realms/sp-customer/protocol/openid-connect/logout \
  ?id_token_hint=<USER_ID_TOKEN> \
  &post_logout_redirect_uri=http://localhost:5173 \
  &client_id=<CLIENT_UUID>

# OR use refresh token revocation:
curl -X POST http://localhost:9090/realms/sp-customer/protocol/openid-connect/logout \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=<CLIENT_UUID>" \
  -d "refresh_token=<REFRESH_TOKEN>"

# Verify logout:
# 1. Try to use the old access_token - should fail (401)
# 2. Try to refresh with old refresh_token - should fail
# 3. Try to access Keycloak account page - should require login
```

### Test SSO (Single Sign-On)

```bash
# 1. Login to SP-Customer realm app (as shown above)
# 2. Open new tab/window and navigate to another SP-Customer app
# 3. User should be automatically logged in (SSO session active)
# 4. No re-authentication required

# Test SSO across realms:
# - Login via SP-Customer → IdP-Customer (federated)
# - Navigate to another app using IdP-Customer directly
# - Should auto-authenticate (same IdP session)
```

### Test Token Refresh

```bash
# Get initial tokens
ACCESS_TOKEN="<access_token>"
REFRESH_TOKEN="<refresh_token>"
CLIENT_ID="<client_uuid>"

# Wait for access token to expire (5 minutes) or use expired token

# Refresh the access token:
curl -X POST http://localhost:9090/realms/sp-customer/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=refresh_token" \
  -d "refresh_token=$REFRESH_TOKEN" \
  -d "client_id=$CLIENT_ID"

# Response includes new access_token, refresh_token, and id_token
```

### Get User Passwords for Testing

```bash
cd users/idp-customer

# Get all user credentials
terraform output -json user_credentials

# Get specific user's password
terraform output -json user_passwords | jq -r '.["john.doe@idp-customer.com"]'

# Get user with groups
terraform output -json user_credentials | jq -r '.["john.doe@idp-customer.com"]'
```

### Verify Federation

```bash
# Check IdP configuration
cd config/idp-provider/sp-customer
terraform output provider_details

# Check broker client
cd app/idp-customer/pkce
terraform output clients
```

## 🛠️ Troubleshooting

### "Account already exists" Error

**Problem**: User exists in SP-Customer but not linked to IdP-Customer

**Solution**:
1. Go to Keycloak Admin Console: http://localhost:9090/admin
2. Switch to `sp-customer` realm
3. Users → Search for the email
4. Delete the user
5. Try logging in again

### "Missing parameter: code_challenge_method" Error

**Problem**: PKCE not enabled on IdP provider

**Solution**: Already fixed! `pkce_enabled: true` in `idpprovider.yml`

### "Invalid redirect_uri" Error

**Problem**: Redirect URI not registered

**Solution**: Add the URI to `redirect_uris` in `apps.yaml`

### "Token signature validation failed"

**Problem**: JWKS URL misconfigured

**Solution**: Verify endpoints in `idpprovider.yml` match IdP-Customer realm

## 📚 Documentation

Each directory contains a README explaining its purpose:

- **config/README.md** - Realm and IdP configuration
- **app/README.md** - Client/application configuration
- **users/README.md** - User management

## 🔄 Deployment Order

When setting up from scratch:

1. **Realms** → `config/realm/*/`
2. **Users** → `users/*/`
3. **Broker Clients** → `app/idp-customer/pkce/`
4. **Identity Providers** → `config/idp-provider/sp-customer/`
5. **PKCE Clients** → `app/sp-customer/pkce/`

## 🌟 Features

- ✅ Multi-realm architecture
- ✅ Identity federation with PKCE
- ✅ YAML-based configuration (no code changes)
- ✅ Protocol mappers (user attributes, audience)
- ✅ CSV-based user management
- ✅ Auto-generated passwords
- ✅ Email as username
- ✅ Token configuration
- ✅ Security defenses
- ✅ Infrastructure as Code

## 📞 Support

For issues or questions:
1. Check troubleshooting section above
2. Review individual directory READMEs
3. Check Terraform outputs for configuration details
4. Review Keycloak logs: `docker logs keycloak` (if using Docker)

## 📜 License

This project is for educational and development purposes.

---

**Built with ❤️ using Terraform + Keycloak + YAML**
