# PKCE OAuth Clients Configuration

This directory manages PKCE (Proof Key for Code Exchange) OAuth clients for Keycloak using Terraform.

## 📋 Overview

PKCE clients use the **Authorization Code Flow with PKCE** (RFC 7636), which is the most secure OAuth 2.0 flow for public clients like web applications, SPAs, and mobile apps where the client secret cannot be securely stored.

## 🏗️ Architecture & Logic

### How It Works

```
apps.yaml (Configuration)
    ↓
Terraform reads YAML and converts to map
    ↓
For each client in the map:
    1. Generate stable UUID (based on client_id)
    2. Create Keycloak OpenID client (PUBLIC type)
    3. Enable PKCE with S256 challenge method
    4. Configure redirect URIs and CORS origins
    5. Create custom client scope
    6. Add audience protocol mapper
    ↓
Output client details (UUIDs, URLs, etc.)
```

### Key Components

#### 1. **apps.yaml** - Client Configuration
```yaml
realm: customer                    # Target Keycloak realm

clients:                          # Array of PKCE clients
  - client_id: webapp-pkce        # Unique identifier (used as Terraform key)
    name: Web Application (PKCE)  # Display name in Keycloak
    enabled: true                 # Enable/disable client
    
    pkce:
      challenge_method: S256      # SHA-256 hashing (most secure)
    
    redirect_uris:                # Where Keycloak redirects after login
      - http://localhost:5173/callback
    
    web_origins:                  # CORS allowed origins
      - http://localhost:5173
    
    token_settings:
      access_token_lifespan: 300  # 5 minutes
      session_idle_timeout: 1800  # 30 minutes
      session_max_lifespan: 36000 # 10 hours
    
    consent_required: false       # Skip consent screen
```

#### 2. **main.tf** - Terraform Logic

**Step 1: Parse YAML Configuration**
```hcl
locals {
  config  = yamldecode(file("${path.module}/apps.yaml"))
  # Convert array to map using client_id as key
  clients = { for idx, client in local.config.clients : client.client_id => client }
}
```

**Step 2: Generate Stable UUIDs**
```hcl
resource "random_uuid" "client" {
  for_each = local.clients
  
  keepers = {
    client_id = each.value.client_id  # UUID only changes if client_id changes
  }
}
```
- **Why UUIDs?** Keycloak requires unique client_id values
- **Why keepers?** Prevents UUID regeneration on every terraform apply
- **Stability:** UUID stays same unless client_id in YAML changes

**Step 3: Create PKCE Clients**
```hcl
resource "keycloak_openid_client" "pkce" {
  for_each = local.clients
  
  lifecycle {
    ignore_changes = [name]  # Prevent recreation if name changes in Keycloak UI
  }

  realm_id  = local.config.realm
  client_id = random_uuid.client[each.key].result  # Use generated UUID
  name      = each.value.name
  enabled   = each.value.enabled

  access_type           = "PUBLIC"     # No client secret (public client)
  standard_flow_enabled = true         # Authorization Code Flow
  direct_access_grants_enabled = false # Disable password grant
  implicit_flow_enabled = false        # Disable deprecated implicit flow
  service_accounts_enabled = false     # Disable M2M flow

  # PKCE Configuration - prevents authorization code interception
  pkce_code_challenge_method = each.value.pkce.challenge_method

  valid_redirect_uris = each.value.redirect_uris  # Where to redirect after login
  web_origins         = each.value.web_origins    # CORS configuration

  # Token lifespans
  access_token_lifespan       = tostring(each.value.token_settings.access_token_lifespan)
  client_session_idle_timeout = tostring(each.value.token_settings.session_idle_timeout)
  client_session_max_lifespan = tostring(each.value.token_settings.session_max_lifespan)

  consent_required = each.value.consent_required
}
```

**Step 4: Create Client Scopes**
```hcl
resource "keycloak_openid_client_scope" "pkce_scope" {
  for_each = local.clients

  realm_id               = local.config.realm
  name                   = "${each.value.client_id}-scope"
  description            = "Custom scope for ${each.value.name}"
  include_in_token_scope = true  # Include in access tokens

  gui_order = 1
}
```

**Step 5: Add Audience Mappers**
```hcl
resource "keycloak_openid_audience_protocol_mapper" "pkce_audience" {
  for_each = local.clients

  realm_id  = local.config.realm
  client_id = keycloak_openid_client.pkce[each.key].id
  name      = "audience-mapper"

  included_client_audience = keycloak_openid_client.pkce[each.key].client_id
  add_to_id_token          = true   # Include in ID token
  add_to_access_token      = true   # Include in access token
}
```

#### 3. **outputs.tf** - Retrieve Client Information

```hcl
output "pkce_clients" {
  description = "All PKCE clients configuration"
  value = {
    for key, client in keycloak_openid_client.pkce : key => {
      client_id          = random_uuid.client[key].result  # The UUID
      client_name        = client.name
      client_type        = "PUBLIC"
      flow_type          = "Authorization Code + PKCE"
      redirect_uris      = client.valid_redirect_uris
      web_origins        = client.web_origins
      authorization_url  = "${var.keycloak_url}/realms/${local.config.realm}/protocol/openid-connect/auth"
      token_url          = "${var.keycloak_url}/realms/${local.config.realm}/protocol/openid-connect/token"
      userinfo_url       = "${var.keycloak_url}/realms/${local.config.realm}/protocol/openid-connect/userinfo"
      logout_url         = "${var.keycloak_url}/realms/${local.config.realm}/protocol/openid-connect/logout"
      pkce_method        = "S256"
      scopes             = ["openid", "profile", "email"]
    }
  }
}
```

## 🚀 Usage

### 1. Configure Your Clients

Edit `apps.yaml` to add/modify PKCE clients:

```yaml
realm: customer

clients:
  - client_id: my-webapp
    name: My Web Application
    enabled: true
    pkce:
      challenge_method: S256
    redirect_uris:
      - http://localhost:3000/callback
      - https://myapp.com/callback
    web_origins:
      - http://localhost:3000
      - https://myapp.com
    token_settings:
      access_token_lifespan: 300
      session_idle_timeout: 1800
      session_max_lifespan: 36000
    consent_required: false
```

### 2. Deploy with Terraform

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply configuration
terraform apply
```

### 3. Retrieve Client Information

```bash
# Get all PKCE clients
terraform output -json pkce_clients | jq

# Get specific client's UUID
terraform output -json pkce_clients | jq '.["webapp-pkce"].client_id'

# Get authorization URL for a client
terraform output -json pkce_clients | jq -r '.["webapp-pkce"].authorization_url'

# Get all client IDs
terraform output -json pkce_clients | jq 'to_entries | map({name: .key, client_id: .value.client_id})'
```

## 🔐 PKCE Flow Explained

### What is PKCE?

PKCE (Proof Key for Code Exchange) prevents authorization code interception attacks. Here's how it works:

```
1. App generates random "code_verifier" (43-128 characters)
   Example: dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk

2. App creates "code_challenge" from code_verifier
   code_challenge = BASE64URL(SHA256(code_verifier))
   
3. App redirects user to Keycloak with code_challenge
   https://keycloak.com/auth?
     client_id=<UUID>&
     redirect_uri=http://localhost:5173/callback&
     response_type=code&
     scope=openid profile email&
     code_challenge=<CODE_CHALLENGE>&
     code_challenge_method=S256
   
4. User authenticates → Keycloak redirects with authorization code
   http://localhost:5173/callback?code=<AUTH_CODE>
   
5. App exchanges code + code_verifier for tokens
   POST /token
   {
     grant_type: "authorization_code",
     client_id: "<UUID>",
     code: "<AUTH_CODE>",
     redirect_uri: "http://localhost:5173/callback",
     code_verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
   }
   
6. Keycloak verifies: SHA256(code_verifier) == stored code_challenge
   ✓ If match → issues access_token, id_token, refresh_token
   ✗ If no match → rejects request
```

### Security Benefits

- **No Client Secret Required**: Safe for public clients (SPAs, mobile apps)
- **Code Interception Protection**: Even if auth code is stolen, attacker can't exchange it without code_verifier
- **Dynamic Verification**: Each auth request uses unique code_verifier/challenge pair

## 📊 Example Implementation (JavaScript)

```javascript
// 1. Generate code_verifier and code_challenge
function generateCodeVerifier() {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return base64URLEncode(array);
}

function base64URLEncode(buffer) {
  return btoa(String.fromCharCode(...new Uint8Array(buffer)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

async function generateCodeChallenge(verifier) {
  const encoder = new TextEncoder();
  const data = encoder.encode(verifier);
  const hash = await crypto.subtle.digest('SHA-256', data);
  return base64URLEncode(hash);
}

// 2. Redirect to authorization URL
async function login() {
  const codeVerifier = generateCodeVerifier();
  const codeChallenge = await generateCodeChallenge(codeVerifier);
  
  // Store verifier in sessionStorage for later
  sessionStorage.setItem('code_verifier', codeVerifier);
  
  const authUrl = new URL('http://localhost:8080/realms/customer/protocol/openid-connect/auth');
  authUrl.searchParams.set('client_id', '<YOUR_CLIENT_UUID>');
  authUrl.searchParams.set('redirect_uri', 'http://localhost:5173/callback');
  authUrl.searchParams.set('response_type', 'code');
  authUrl.searchParams.set('scope', 'openid profile email');
  authUrl.searchParams.set('code_challenge', codeChallenge);
  authUrl.searchParams.set('code_challenge_method', 'S256');
  
  window.location.href = authUrl.toString();
}

// 3. Handle callback and exchange code for tokens
async function handleCallback() {
  const urlParams = new URLSearchParams(window.location.search);
  const code = urlParams.get('code');
  const codeVerifier = sessionStorage.getItem('code_verifier');
  
  const response = await fetch('http://localhost:8080/realms/customer/protocol/openid-connect/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: '<YOUR_CLIENT_UUID>',
      code: code,
      redirect_uri: 'http://localhost:5173/callback',
      code_verifier: codeVerifier
    })
  });
  
  const tokens = await response.json();
  // tokens = { access_token, id_token, refresh_token, expires_in, ... }
  
  sessionStorage.removeItem('code_verifier');
  return tokens;
}
```

## 🔧 Configuration Options

### Token Lifespans

| Setting | Default | Recommended | Description |
|---------|---------|-------------|-------------|
| `access_token_lifespan` | 300s (5m) | 300-600s | How long access token is valid |
| `session_idle_timeout` | 1800s (30m) | 1800-3600s | Max idle time before re-auth |
| `session_max_lifespan` | 36000s (10h) | 28800-43200s | Max session duration |

### PKCE Challenge Methods

| Method | Algorithm | Security | Recommendation |
|--------|-----------|----------|----------------|
| `S256` | SHA-256 | High ✅ | **Always use this** |
| `plain` | None | Low ⚠️ | Never use (deprecated) |

### Redirect URIs

- Must match exactly (including trailing slashes)
- Use `http://localhost` for development
- Use `https://` for production
- Mobile apps: Use custom schemes (e.g., `myapp://callback`)

### Web Origins

- Controls CORS policy
- Add all domains that will make requests to Keycloak
- Use `*` only for development (security risk in production)

## 📝 Adding Multiple Clients

To add more PKCE clients, simply add entries to the `clients` array in `apps.yaml`:

```yaml
clients:
  - client_id: webapp-pkce
    name: Web Application
    # ... config
    
  - client_id: mobile-app-pkce
    name: Mobile App
    # ... config
    
  - client_id: admin-portal-pkce
    name: Admin Portal
    # ... config
```

Each client will automatically get:
- Its own stable UUID
- Its own client scope
- Its own audience mapper
- Independent configuration

## 🔍 Troubleshooting

### Issue: "Invalid redirect_uri"
**Cause:** The redirect_uri in your app doesn't match `apps.yaml`  
**Solution:** Ensure exact match including protocol, domain, port, path, and trailing slashes

### Issue: "CORS error - No 'Access-Control-Allow-Origin' header"
**Full Error:**
```
Access to fetch at 'http://localhost:8081/userinfo' from origin 'http://localhost:5173' 
has been blocked by CORS policy: Response to preflight request doesn't pass access 
control check: No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

**Common Causes & Solutions:**

1. **Wrong Keycloak URL/Port**
   - ❌ Wrong: `http://localhost:8081/userinfo`
   - ✅ Correct: `http://localhost:8080/realms/customer/protocol/openid-connect/userinfo`
   
   **Fix:** Get the correct userinfo URL from Terraform:
   ```bash
   terraform output -json pkce_clients | jq -r '.["webapp-pkce"].userinfo_url'
   # Output: http://localhost:8080/realms/customer/protocol/openid-connect/userinfo
   ```

2. **Origin not in web_origins**
   - Check if your app's origin is configured:
   ```bash
   terraform output -json pkce_clients | jq -r '.["webapp-pkce"].web_origins'
   ```
   
   **Fix:** Add your origin to `apps.yaml`:
   ```yaml
   web_origins:
     - http://localhost:5173  # Your app's origin
     - http://localhost:3000  # Additional origins
   ```
   Then apply: `terraform apply`

3. **Using wrong client_id**
   - Ensure you're using the correct UUID:
   ```bash
   terraform output -json pkce_clients | jq -r '.["webapp-pkce"].client_id'
   # Output: fae7e8da-659e-63f9-8294-29e1c4384699
   ```

4. **Keycloak CORS not applied**
   - Verify client configuration in Keycloak Admin Console:
     - Go to: Clients → [Your Client UUID] → Settings
     - Check "Web Origins" field contains your origin
     - Check "Valid Redirect URIs" includes your callback

**Quick Fix for Your Error:**

Your app is calling the wrong endpoint. Update your code:

```javascript
// ❌ WRONG - Don't use this
const response = await fetch('http://localhost:8081/userinfo', {
  headers: { 'Authorization': `Bearer ${accessToken}` }
});

// ✅ CORRECT - Use the proper Keycloak endpoint
const USERINFO_URL = 'http://localhost:8080/realms/customer/protocol/openid-connect/userinfo';
const response = await fetch(USERINFO_URL, {
  headers: { 'Authorization': `Bearer ${accessToken}` }
});
```

**Get all correct URLs:**
```bash
# Authorization URL
terraform output -json pkce_clients | jq -r '.["webapp-pkce"].authorization_url'

# Token URL
terraform output -json pkce_clients | jq -r '.["webapp-pkce"].token_url'

# Userinfo URL
terraform output -json pkce_clients | jq -r '.["webapp-pkce"].userinfo_url'

# Logout URL
terraform output -json pkce_clients | jq -r '.["webapp-pkce"].logout_url'
```

**Create a config file for your app:**
```bash
# Generate a config.json with all necessary URLs
cat > config.json <<EOF
{
  "clientId": "$(terraform output -json pkce_clients | jq -r '.["webapp-pkce"].client_id')",
  "authorizationUrl": "$(terraform output -json pkce_clients | jq -r '.["webapp-pkce"].authorization_url')",
  "tokenUrl": "$(terraform output -json pkce_clients | jq -r '.["webapp-pkce"].token_url')",
  "userinfoUrl": "$(terraform output -json pkce_clients | jq -r '.["webapp-pkce"].userinfo_url')",
  "logoutUrl": "$(terraform output -json pkce_clients | jq -r '.["webapp-pkce"].logout_url')",
  "redirectUri": "http://localhost:5173/callback",
  "scopes": ["openid", "profile", "email"]
}
EOF
cat config.json
```

### Issue: "Invalid code_verifier"
**Cause:** Code verifier doesn't match the code challenge  
**Solution:** Ensure you're sending the same verifier used to generate the challenge

### Issue: "Client UUID changes on every apply"
**Cause:** `keepers` in random_uuid not properly configured  
**Solution:** This shouldn't happen - check that `client_id` in YAML is stable

### Issue: "Token expired"
**Cause:** Access token lifespan too short  
**Solution:** Increase `access_token_lifespan` in `token_settings` (but keep it secure)

## 🛡️ Security Best Practices

1. ✅ **Always use S256** challenge method (never `plain`)
2. ✅ **Keep access tokens short-lived** (5-10 minutes)
3. ✅ **Use HTTPS in production** (not http)
4. ✅ **Validate redirect_uri** strictly (no wildcards)
5. ✅ **Limit web_origins** to known domains
6. ✅ **Store code_verifier securely** (sessionStorage, not localStorage)
7. ✅ **Clear code_verifier** after token exchange
8. ⚠️ **Never log tokens** or code_verifier values

## 📚 References

- [RFC 7636 - PKCE](https://datatracker.ietf.org/doc/html/rfc7636)
- [OAuth 2.0 for Browser-Based Apps](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-browser-based-apps)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak Terraform Provider](https://registry.terraform.io/providers/keycloak/keycloak/latest/docs)
