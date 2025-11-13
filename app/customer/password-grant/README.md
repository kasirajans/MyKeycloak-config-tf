# Password Grant (ROPC) OAuth Clients Configuration

⚠️ **WARNING: This OAuth flow is considered LEGACY and DEPRECATED. Only use for migrating legacy applications that cannot support modern flows like PKCE.**

This directory manages Password Grant OAuth clients for Keycloak using Terraform with the **Resource Owner Password Credentials (ROPC) Flow**.

## 📋 Overview

Password Grant clients use the **Resource Owner Password Credentials (ROPC) Flow** (RFC 6749 Section 4.3), where the application directly collects the user's username and password and exchanges them for tokens. This flow is less secure than PKCE because:

- User credentials are exposed to the application
- No protection against credential interception
- Application must handle credential storage securely
- Not recommended for new applications

**When to use:**
- ✅ Migrating legacy applications that can't support redirect-based flows
- ✅ First-party applications with high trust level
- ✅ Command-line tools or scripts
- ❌ Third-party applications
- ❌ New web or mobile applications (use PKCE instead)

## 🏗️ Architecture & Logic

### How It Works

```
apps.yaml (Configuration)
    ↓
Terraform reads YAML and converts to map
    ↓
For each Password Grant client in the map:
    1. Generate stable UUID (based on client_id)
    2. Generate random 48-char client secret (if CONFIDENTIAL)
    3. Create Keycloak OpenID client (PUBLIC or CONFIDENTIAL)
    4. Enable direct_access_grants (Password Grant flow)
    5. Create custom client scope
    6. Add audience protocol mapper
    ↓
Output client details (UUIDs, secrets for CONFIDENTIAL, URLs)
```

### Key Components

#### 1. **apps.yaml** - Client Configuration
```yaml
realm: customer                           # Target Keycloak realm

clients:                                 # Array of Password Grant clients
  - client_id: legacy-app-password       # Unique identifier (Terraform key)
    name: Legacy Application             # Display name in Keycloak
    description: Legacy app migration    # Optional description
    enabled: true                        # Enable/disable client
    access_type: CONFIDENTIAL            # CONFIDENTIAL or PUBLIC
    
    token_settings:
      access_token_lifespan: 300         # 5 minutes (in seconds)
      refresh_token_lifespan: 1800       # 30 minutes
      session_idle_timeout: 1800         # 30 minutes
      session_max_lifespan: 36000        # 10 hours
    
    consent_required: false              # Skip consent screen
```

**Client Types:**
- **CONFIDENTIAL**: Server-side apps that can securely store client_secret (generates 48-char secret)
- **PUBLIC**: Native/mobile apps that cannot securely store secrets (no secret required)

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
    client_id = each.value.client_id  # UUID regenerates only if client_id changes
  }
}
```

**Step 3: Generate Random Client Secrets (CONFIDENTIAL clients only)**
```hcl
resource "random_password" "client_secret" {
  for_each = {
    for key, client in local.clients : key => client
    if try(client.access_type, "CONFIDENTIAL") == "CONFIDENTIAL"
  }
  
  length  = 48                    # 48-character secret
  special = true
  upper   = true
  lower   = true
  numeric = true
  
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
  
  override_special = "!@#$%^&*()-_=+[]{}:,.<>?"
  
  keepers = {
    client_id = each.value.client_id
  }
}
```
- **Conditional:** Only generates secrets for CONFIDENTIAL clients
- **PUBLIC clients:** No secret generated (not needed)

**Step 4: Create Password Grant Clients**
```hcl
resource "keycloak_openid_client" "password_grant" {
  for_each = local.clients
  
  lifecycle {
    ignore_changes = [name]  # Prevent recreation if name changes in UI
  }

  realm_id  = local.config.realm
  client_id = random_uuid.client[each.key].result
  name      = each.value.name
  enabled   = each.value.enabled

  # Access type: PUBLIC or CONFIDENTIAL
  access_type = try(each.value.access_type, "CONFIDENTIAL")
  
  # Enable ROPC (Resource Owner Password Credentials) flow
  standard_flow_enabled        = false   # Disable auth code flow
  direct_access_grants_enabled = true    # Enable Password Grant
  implicit_flow_enabled        = false   # Disable implicit flow
  service_accounts_enabled     = false   # Disable M2M flow

  # Client secret only for CONFIDENTIAL clients
  client_secret = try(each.value.access_type, "CONFIDENTIAL") == "CONFIDENTIAL" ? random_password.client_secret[each.key].result : null

  # Token settings
  access_token_lifespan       = tostring(each.value.token_settings.access_token_lifespan)
  client_session_idle_timeout = tostring(each.value.token_settings.session_idle_timeout)
  client_session_max_lifespan = tostring(each.value.token_settings.session_max_lifespan)

  # Refresh token settings
  client_offline_session_idle_timeout = tostring(try(each.value.token_settings.refresh_token_lifespan, 1800))

  consent_required = each.value.consent_required
}
```
- **direct_access_grants_enabled = true:** This is what enables the Password Grant flow
- **Conditional secret:** Only set for CONFIDENTIAL clients

#### 3. **outputs.tf** - Retrieve Client Information

```hcl
output "password_grant_clients" {
  description = "All Password Grant clients configuration"
  value = {
    for key, client in keycloak_openid_client.password_grant : key => {
      client_id          = random_uuid.client[key].result
      client_name        = client.name
      client_type        = try(local.clients[key].access_type, "CONFIDENTIAL")
      flow_type          = "Resource Owner Password Credentials (ROPC)"
      token_url          = "${var.keycloak_url}/realms/${local.config.realm}/protocol/openid-connect/token"
      grant_type         = "password"
      has_client_secret  = try(local.clients[key].access_type, "CONFIDENTIAL") == "CONFIDENTIAL"
    }
  }
  sensitive = true
}

output "password_grant_client_secrets" {
  description = "Client secrets for CONFIDENTIAL clients only"
  value = {
    for key, _ in local.clients : key => (
      try(local.clients[key].access_type, "CONFIDENTIAL") == "CONFIDENTIAL" 
      ? random_password.client_secret[key].result 
      : "N/A - Public Client"
    )
  }
  sensitive = true
}
```

## 🚀 Usage

### 1. Configure Your Password Grant Clients

Edit `apps.yaml` to add/modify Password Grant clients:

```yaml
realm: customer

clients:
  # CONFIDENTIAL client (server-side app)
  - client_id: legacy-backend
    name: Legacy Backend Application
    enabled: true
    access_type: CONFIDENTIAL  # Requires client_secret
    
    token_settings:
      access_token_lifespan: 300
      refresh_token_lifespan: 1800
      session_idle_timeout: 1800
      session_max_lifespan: 36000
    
    consent_required: false
  
  # PUBLIC client (mobile/desktop app)
  - client_id: legacy-mobile
    name: Legacy Mobile App
    enabled: true
    access_type: PUBLIC  # No client_secret required
    
    token_settings:
      access_token_lifespan: 600
      refresh_token_lifespan: 3600
      session_idle_timeout: 3600
      session_max_lifespan: 43200
    
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

### 3. Retrieve Client Credentials

#### Get All Password Grant Clients

```bash
# View all client information
terraform output -json password_grant_clients | jq

# View all client secrets (shows "N/A - Public Client" for PUBLIC clients)
terraform output -json password_grant_client_secrets | jq
```

#### Get Specific Client Credentials

```bash
# Get CONFIDENTIAL client credentials
terraform output -json password_grant_clients | jq -r '.["legacy-app-password"].client_id'
terraform output -json password_grant_client_secrets | jq -r '.["legacy-app-password"]'

# Get PUBLIC client UUID (no secret)
terraform output -json password_grant_clients | jq -r '.["mobile-legacy-password"].client_id'
terraform output -json password_grant_client_secrets | jq -r '.["mobile-legacy-password"]'
# Output: "N/A - Public Client"
```

#### Get All Credentials in Table Format

```bash
# List all clients with credentials
for client in $(terraform output -json password_grant_clients | jq -r 'keys[]'); do
  echo "=== $client ==="
  echo "Client ID: $(terraform output -json password_grant_clients | jq -r ".\"$client\".client_id")"
  echo "Type: $(terraform output -json password_grant_clients | jq -r ".\"$client\".client_type")"
  echo "Secret: $(terraform output -json password_grant_client_secrets | jq -r ".\"$client\"")"
  echo "Has Secret: $(terraform output -json password_grant_clients | jq -r ".\"$client\".has_client_secret")"
  echo ""
done
```

### 4. Test Password Grant Flow

#### CONFIDENTIAL Client (with secret)

```bash
# Store credentials
CLIENT_ID=$(terraform output -json password_grant_clients | jq -r '.["legacy-app-password"].client_id')
CLIENT_SECRET=$(terraform output -json password_grant_client_secrets | jq -r '.["legacy-app-password"]')
TOKEN_URL=$(terraform output -json password_grant_clients | jq -r '.["legacy-app-password"].token_url')

# Get tokens using user credentials
curl -X POST "$TOKEN_URL" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "username=user@consumer.com" \
  -d "password=UserPassword123" \
  -d "scope=openid profile email" | jq
```

#### PUBLIC Client (no secret)

```bash
# Store client ID
CLIENT_ID=$(terraform output -json password_grant_clients | jq -r '.["mobile-legacy-password"].client_id')
TOKEN_URL=$(terraform output -json password_grant_clients | jq -r '.["mobile-legacy-password"].token_url')

# Get tokens using user credentials (no client_secret)
curl -X POST "$TOKEN_URL" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=password" \
  -d "client_id=$CLIENT_ID" \
  -d "username=user@consumer.com" \
  -d "password=UserPassword123" \
  -d "scope=openid profile email" | jq
```

### 5. View Usage Examples

```bash
# Get complete usage examples from Terraform
terraform output usage_example
```

## 🔐 Password Grant Flow Explained

### How It Works

```
User enters credentials in application
    ↓
Application sends username + password + client credentials to Keycloak
    ↓
Keycloak validates user credentials
    ↓
If valid → returns access_token, id_token, refresh_token
    ↓
Application uses tokens to access APIs
```

### Detailed Flow

#### CONFIDENTIAL Client Flow

```bash
# Application collects user credentials
username = "user@consumer.com"
password = "UserPassword123"

# Application sends to Keycloak
POST http://localhost:8080/realms/customer/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=password
client_id=<CLIENT_UUID>
client_secret=<48_CHAR_SECRET>
username=user@consumer.com
password=UserPassword123
scope=openid profile email

# Keycloak validates:
# 1. Client credentials (client_id + client_secret)
# 2. User credentials (username + password)

# If both valid, returns:
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 300,
  "refresh_expires_in": 1800,
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6...",
  "token_type": "Bearer",
  "id_token": "eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6...",
  "not-before-policy": 0,
  "session_state": "af234dc3-9472-4d89-b4c5-f97e4a890eb2",
  "scope": "openid profile email"
}
```

#### PUBLIC Client Flow

Same as CONFIDENTIAL, but without `client_secret` parameter:

```bash
POST http://localhost:8080/realms/customer/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=password
client_id=<CLIENT_UUID>
username=user@consumer.com
password=UserPassword123
scope=openid profile email
```

### Security Concerns

⚠️ **Why Password Grant is Deprecated:**

1. **Credentials exposed to application**: The app has direct access to user passwords
2. **No phishing protection**: Users enter credentials into the app, not the identity provider
3. **Credential storage risk**: Apps might improperly store credentials
4. **No MFA support**: Difficult to implement multi-factor authentication
5. **Trust requirement**: User must fully trust the application

**Modern alternative:** Use **PKCE (Authorization Code + PKCE)** flow instead

## 📊 Example Implementations

### cURL Examples

```bash
#!/bin/bash

# CONFIDENTIAL Client
CONFIDENTIAL_CLIENT_ID="uuid-here"
CONFIDENTIAL_SECRET="48-char-secret-here"
TOKEN_URL="http://localhost:8080/realms/customer/protocol/openid-connect/token"

# Get tokens (CONFIDENTIAL)
curl -X POST "$TOKEN_URL" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=password" \
  -d "client_id=$CONFIDENTIAL_CLIENT_ID" \
  -d "client_secret=$CONFIDENTIAL_SECRET" \
  -d "username=user@consumer.com" \
  -d "password=UserPassword123" \
  -d "scope=openid profile email"

# PUBLIC Client
PUBLIC_CLIENT_ID="uuid-here"

# Get tokens (PUBLIC - no secret)
curl -X POST "$TOKEN_URL" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=password" \
  -d "client_id=$PUBLIC_CLIENT_ID" \
  -d "username=user@consumer.com" \
  -d "password=UserPassword123" \
  -d "scope=openid profile email"
```

### Node.js Example

```javascript
const axios = require('axios');

// CONFIDENTIAL Client Configuration
const CONFIDENTIAL_CLIENT_ID = 'uuid-here';
const CONFIDENTIAL_SECRET = '48-char-secret-here';
const TOKEN_URL = 'http://localhost:8080/realms/customer/protocol/openid-connect/token';

async function getTokensConfidential(username, password) {
  const params = new URLSearchParams();
  params.append('grant_type', 'password');
  params.append('client_id', CONFIDENTIAL_CLIENT_ID);
  params.append('client_secret', CONFIDENTIAL_SECRET);
  params.append('username', username);
  params.append('password', password);
  params.append('scope', 'openid profile email');

  try {
    const response = await axios.post(TOKEN_URL, params, {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    });
    
    return {
      accessToken: response.data.access_token,
      refreshToken: response.data.refresh_token,
      idToken: response.data.id_token,
      expiresIn: response.data.expires_in
    };
  } catch (error) {
    console.error('Authentication failed:', error.response?.data);
    throw error;
  }
}

// PUBLIC Client Configuration
const PUBLIC_CLIENT_ID = 'uuid-here';

async function getTokensPublic(username, password) {
  const params = new URLSearchParams();
  params.append('grant_type', 'password');
  params.append('client_id', PUBLIC_CLIENT_ID);
  // No client_secret for PUBLIC clients
  params.append('username', username);
  params.append('password', password);
  params.append('scope', 'openid profile email');

  try {
    const response = await axios.post(TOKEN_URL, params, {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    });
    
    return {
      accessToken: response.data.access_token,
      refreshToken: response.data.refresh_token,
      idToken: response.data.id_token,
      expiresIn: response.data.expires_in
    };
  } catch (error) {
    console.error('Authentication failed:', error.response?.data);
    throw error;
  }
}

// Usage
(async () => {
  try {
    // CONFIDENTIAL client
    const tokens = await getTokensConfidential('user@consumer.com', 'UserPassword123');
    console.log('Access Token:', tokens.accessToken);
    
    // PUBLIC client
    const publicTokens = await getTokensPublic('user@consumer.com', 'UserPassword123');
    console.log('Access Token (Public):', publicTokens.accessToken);
  } catch (error) {
    console.error('Error:', error.message);
  }
})();
```

### Python Example

```python
import requests

# CONFIDENTIAL Client Configuration
CONFIDENTIAL_CLIENT_ID = "uuid-here"
CONFIDENTIAL_SECRET = "48-char-secret-here"
TOKEN_URL = "http://localhost:8080/realms/customer/protocol/openid-connect/token"

def get_tokens_confidential(username: str, password: str) -> dict:
    """Get tokens using CONFIDENTIAL client (with secret)"""
    data = {
        'grant_type': 'password',
        'client_id': CONFIDENTIAL_CLIENT_ID,
        'client_secret': CONFIDENTIAL_SECRET,
        'username': username,
        'password': password,
        'scope': 'openid profile email'
    }
    
    response = requests.post(
        TOKEN_URL,
        data=data,
        headers={'Content-Type': 'application/x-www-form-urlencoded'}
    )
    
    response.raise_for_status()
    return response.json()

# PUBLIC Client Configuration
PUBLIC_CLIENT_ID = "uuid-here"

def get_tokens_public(username: str, password: str) -> dict:
    """Get tokens using PUBLIC client (no secret)"""
    data = {
        'grant_type': 'password',
        'client_id': PUBLIC_CLIENT_ID,
        # No client_secret for PUBLIC clients
        'username': username,
        'password': password,
        'scope': 'openid profile email'
    }
    
    response = requests.post(
        TOKEN_URL,
        data=data,
        headers={'Content-Type': 'application/x-www-form-urlencoded'}
    )
    
    response.raise_for_status()
    return response.json()

# Usage
if __name__ == '__main__':
    try:
        # CONFIDENTIAL client
        tokens = get_tokens_confidential('user@consumer.com', 'UserPassword123')
        print(f'Access Token: {tokens["access_token"]}')
        print(f'Expires In: {tokens["expires_in"]} seconds')
        
        # PUBLIC client
        public_tokens = get_tokens_public('user@consumer.com', 'UserPassword123')
        print(f'Access Token (Public): {public_tokens["access_token"]}')
        
    except requests.exceptions.HTTPError as e:
        print(f'Authentication failed: {e.response.json()}')
```

### Java Spring Boot Example

```java
import org.springframework.http.*;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

public class PasswordGrantAuthService {
    
    // CONFIDENTIAL Client
    private static final String CONFIDENTIAL_CLIENT_ID = "uuid-here";
    private static final String CONFIDENTIAL_SECRET = "48-char-secret-here";
    
    // PUBLIC Client
    private static final String PUBLIC_CLIENT_ID = "uuid-here";
    
    private static final String TOKEN_URL = "http://localhost:8080/realms/customer/protocol/openid-connect/token";
    
    private final RestTemplate restTemplate = new RestTemplate();
    
    public TokenResponse getTokensConfidential(String username, String password) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
        
        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        body.add("grant_type", "password");
        body.add("client_id", CONFIDENTIAL_CLIENT_ID);
        body.add("client_secret", CONFIDENTIAL_SECRET);
        body.add("username", username);
        body.add("password", password);
        body.add("scope", "openid profile email");
        
        HttpEntity<MultiValueMap<String, String>> request = new HttpEntity<>(body, headers);
        
        ResponseEntity<TokenResponse> response = restTemplate.exchange(
            TOKEN_URL,
            HttpMethod.POST,
            request,
            TokenResponse.class
        );
        
        return response.getBody();
    }
    
    public TokenResponse getTokensPublic(String username, String password) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
        
        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        body.add("grant_type", "password");
        body.add("client_id", PUBLIC_CLIENT_ID);
        // No client_secret for PUBLIC clients
        body.add("username", username);
        body.add("password", password);
        body.add("scope", "openid profile email");
        
        HttpEntity<MultiValueMap<String, String>> request = new HttpEntity<>(body, headers);
        
        ResponseEntity<TokenResponse> response = restTemplate.exchange(
            TOKEN_URL,
            HttpMethod.POST,
            request,
            TokenResponse.class
        );
        
        return response.getBody();
    }
    
    // Token Response DTO
    public static class TokenResponse {
        private String access_token;
        private String refresh_token;
        private String id_token;
        private int expires_in;
        private int refresh_expires_in;
        private String token_type;
        private String scope;
        
        // Getters and setters
        public String getAccessToken() { return access_token; }
        public void setAccessToken(String access_token) { this.access_token = access_token; }
        
        public String getRefreshToken() { return refresh_token; }
        public void setRefreshToken(String refresh_token) { this.refresh_token = refresh_token; }
        
        public String getIdToken() { return id_token; }
        public void setIdToken(String id_token) { this.id_token = id_token; }
        
        public int getExpiresIn() { return expires_in; }
        public void setExpiresIn(int expires_in) { this.expires_in = expires_in; }
        
        public int getRefreshExpiresIn() { return refresh_expires_in; }
        public void setRefreshExpiresIn(int refresh_expires_in) { this.refresh_expires_in = refresh_expires_in; }
        
        public String getTokenType() { return token_type; }
        public void setTokenType(String token_type) { this.token_type = token_type; }
        
        public String getScope() { return scope; }
        public void setScope(String scope) { this.scope = scope; }
    }
}
```

## 🔧 Configuration Options

### Client Types

| Type | Description | Client Secret | Use Case |
|------|-------------|---------------|----------|
| **CONFIDENTIAL** | Server-side apps | ✅ Required (48-char auto-generated) | Backend services, web servers |
| **PUBLIC** | Client-side apps | ❌ Not required | Mobile apps, desktop apps, CLI tools |

### Token Lifespans

| Setting | Typical Value | Range | Description |
|---------|--------------|-------|-------------|
| `access_token_lifespan` | 300s (5m) | 300-600s | How long access token is valid |
| `refresh_token_lifespan` | 1800s (30m) | 1800-3600s | How long refresh token is valid |
| `session_idle_timeout` | 1800s (30m) | 1800-3600s | Max idle time before re-auth |
| `session_max_lifespan` | 36000s (10h) | 28800-43200s | Max session duration |

### When to Use Each Type

**Use CONFIDENTIAL when:**
- Application runs on a server you control
- Client secret can be securely stored
- Backend-to-backend authentication
- Web application with server-side component

**Use PUBLIC when:**
- Mobile or desktop application
- Client secret cannot be securely stored
- Credentials would be extractable from app binary
- Command-line tools or scripts

## 📝 Adding Multiple Password Grant Clients

Add more entries to the `clients` array in `apps.yaml`:

```yaml
clients:
  # CONFIDENTIAL server-side app
  - client_id: legacy-backend
    name: Legacy Backend
    enabled: true
    access_type: CONFIDENTIAL
    token_settings:
      access_token_lifespan: 300
      refresh_token_lifespan: 1800
      session_idle_timeout: 1800
      session_max_lifespan: 36000
    consent_required: false
    
  # PUBLIC mobile app
  - client_id: legacy-mobile
    name: Legacy Mobile App
    enabled: true
    access_type: PUBLIC
    token_settings:
      access_token_lifespan: 600
      refresh_token_lifespan: 3600
      session_idle_timeout: 3600
      session_max_lifespan: 43200
    consent_required: false
    
  # PUBLIC CLI tool
  - client_id: admin-cli-tool
    name: Admin CLI Tool
    enabled: true
    access_type: PUBLIC
    token_settings:
      access_token_lifespan: 1800
      refresh_token_lifespan: 7200
      session_idle_timeout: 7200
      session_max_lifespan: 86400
    consent_required: false
```

## 🔍 Troubleshooting

### Issue: "Invalid user credentials"
**Cause:** Wrong username or password  
**Solution:** 
- Verify user exists in Keycloak realm
- Check password is correct
- Ensure user account is enabled
- Check user email is verified (if required)

### Issue: "Invalid client credentials" (CONFIDENTIAL only)
**Cause:** Wrong client_id or client_secret  
**Solution:**
```bash
terraform output -json password_grant_clients | jq -r '.["legacy-app-password"].client_id'
terraform output -json password_grant_client_secrets | jq -r '.["legacy-app-password"]'
```

### Issue: "Client secret keeps changing"
**Cause:** Keepers not properly configured (shouldn't happen)  
**Solution:** Verify `client_id` in YAML is stable

### Issue: "User not found"
**Cause:** User doesn't exist in the specified realm  
**Solution:** Create user in Keycloak or check realm name

### Issue: "Account is not fully set up"
**Cause:** User account requires additional actions (email verification, password change, etc.)  
**Solution:** Complete required actions in Keycloak admin console

### Issue: "Access denied"
**Cause:** User doesn't have permission to access client  
**Solution:** Check client role mappings and user permissions

## 🛡️ Security Best Practices

### ⚠️ Critical Security Considerations

1. **Migrate to PKCE when possible**
   - Password Grant is deprecated for good reasons
   - PKCE provides better security without credential exposure
   - Plan migration path to modern OAuth flows

2. **Never log user credentials**
   - Don't log username or password
   - Don't include credentials in error messages
   - Don't store plain-text passwords

3. **Secure credential transmission**
   - ✅ Always use HTTPS in production
   - ❌ Never send credentials over HTTP
   - Consider certificate pinning for mobile apps

4. **Client secret protection (CONFIDENTIAL clients)**
   - Store in environment variables or secrets manager
   - Never hardcode in source code
   - Never commit to version control
   - Rotate periodically

5. **Token management**
   - Keep access tokens short-lived (5-10 minutes)
   - Implement refresh token rotation
   - Securely store tokens (encrypted storage, keychain)
   - Clear tokens on logout

6. **Rate limiting**
   - Implement rate limiting on token endpoint
   - Prevent brute-force attacks
   - Monitor for unusual patterns

7. **Input validation**
   - Validate username format
   - Check password complexity
   - Sanitize all inputs

8. **Monitoring and auditing**
   - Log authentication attempts
   - Alert on multiple failed attempts
   - Track token usage patterns
   - Monitor for credential stuffing attacks

### Migration Path from Password Grant

If you're using Password Grant, plan to migrate:

```
Current: Password Grant
    ↓
Step 1: Implement refresh tokens
    ↓
Step 2: Add web view for authentication
    ↓
Step 3: Implement PKCE flow in parallel
    ↓
Step 4: Gradually migrate users to PKCE
    ↓
Step 5: Deprecate Password Grant
    ↓
Future: PKCE only
```

## 🔄 Refresh Token Usage

### Why Use Refresh Tokens?

- Avoid storing user credentials
- Get new access tokens without re-authentication
- Improve security (refresh tokens can be revoked)

### Refresh Token Request

```bash
REFRESH_TOKEN="<refresh_token_from_login>"

# CONFIDENTIAL client
curl -X POST "$TOKEN_URL" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=refresh_token" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "refresh_token=$REFRESH_TOKEN"

# PUBLIC client
curl -X POST "$TOKEN_URL" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=refresh_token" \
  -d "client_id=$CLIENT_ID" \
  -d "refresh_token=$REFRESH_TOKEN"
```

## 📚 References

- [RFC 6749 Section 4.3 - Resource Owner Password Credentials Grant](https://datatracker.ietf.org/doc/html/rfc6749#section-4.3)
- [OAuth 2.0 Security Best Current Practice](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics)
- [Why the Resource Owner Password Credentials Grant is deprecated](https://www.oauth.com/oauth2-servers/access-tokens/password-grant/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak Terraform Provider](https://registry.terraform.io/providers/keycloak/keycloak/latest/docs)

## ⚡ Quick Reference

### CONFIDENTIAL Client Token Request
```bash
curl -X POST 'http://localhost:8080/realms/customer/protocol/openid-connect/token' \
  -d 'grant_type=password' \
  -d 'client_id=<UUID>' \
  -d 'client_secret=<SECRET>' \
  -d 'username=user@example.com' \
  -d 'password=UserPass123' \
  -d 'scope=openid profile email'
```

### PUBLIC Client Token Request
```bash
curl -X POST 'http://localhost:8080/realms/customer/protocol/openid-connect/token' \
  -d 'grant_type=password' \
  -d 'client_id=<UUID>' \
  -d 'username=user@example.com' \
  -d 'password=UserPass123' \
  -d 'scope=openid profile email'
```

### Get Client Credentials
```bash
terraform output -json password_grant_clients | jq
terraform output -json password_grant_client_secrets | jq
```
