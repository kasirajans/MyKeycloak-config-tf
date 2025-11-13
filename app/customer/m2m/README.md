# M2M (Machine-to-Machine) OAuth Clients Configuration

This directory manages M2M OAuth clients for Keycloak using Terraform with the **Client Credentials Flow**.

## 📋 Overview

M2M (Machine-to-Machine) clients use the **Client Credentials Flow** (RFC 6749 Section 4.4), designed for service-to-service authentication where there is no user interaction. These are CONFIDENTIAL clients that authenticate using a client_id and client_secret.

## 🏗️ Architecture & Logic

### How It Works

```
apps.yaml (Configuration)
    ↓
Terraform reads YAML and converts to map
    ↓
For each M2M client in the map:
    1. Generate stable UUID (based on client_id)
    2. Generate random 48-char client secret
    3. Create Keycloak OpenID client (CONFIDENTIAL type)
    4. Enable service_accounts (Client Credentials flow)
    5. Create custom client scope
    6. Assign service account roles (if specified)
    7. Add audience protocol mapper
    ↓
Output client details (UUIDs, secrets, URLs)
```

### Key Components

#### 1. **apps.yaml** - Client Configuration
```yaml
realm: customer                         # Target Keycloak realm

clients:                               # Array of M2M clients
  - client_id: backend-service-m2m     # Unique identifier (Terraform key)
    name: Backend Service (M2M)        # Display name in Keycloak
    description: Backend service auth  # Optional description
    enabled: true                      # Enable/disable client
    
    token_settings:
      access_token_lifespan: 3600      # 1 hour (in seconds)
    
    service_account_roles: []          # Realm roles for service account
      # - view-users                   # Example: grant view-users role
      # - manage-users                 # Example: grant manage-users role
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
    client_id = each.value.client_id  # UUID regenerates only if client_id changes
  }
}
```
- **Purpose:** Each M2M client gets a unique UUID as its client_id
- **Stability:** UUID persists across terraform applies unless client_id changes

**Step 3: Generate Random Client Secrets (48 characters)**
```hcl
resource "random_password" "client_secret" {
  for_each = local.clients
  
  length  = 48                    # 48-character secret
  special = true
  upper   = true
  lower   = true
  numeric = true
  
  min_upper   = 2                 # Minimum 2 uppercase letters
  min_lower   = 2                 # Minimum 2 lowercase letters
  min_numeric = 2                 # Minimum 2 digits
  min_special = 2                 # Minimum 2 special characters
  
  override_special = "!@#$%^&*()-_=+[]{}:,.<>?"
  
  keepers = {
    client_id = each.value.client_id  # Regenerate if client_id changes
  }
}
```
- **Security:** Auto-generated cryptographically secure secrets
- **Length:** 48 characters with complexity requirements
- **Persistence:** Secret stays same across applies (stored in state)

**Step 4: Create M2M Clients**
```hcl
resource "keycloak_openid_client" "m2m" {
  for_each = local.clients
  
  lifecycle {
    ignore_changes = [name]  # Prevent recreation if name changes in UI
  }

  realm_id  = local.config.realm
  client_id = random_uuid.client[each.key].result  # Use generated UUID
  name      = each.value.name
  enabled   = each.value.enabled

  access_type                  = "CONFIDENTIAL"  # Requires client_secret
  standard_flow_enabled        = false           # Disable auth code flow
  direct_access_grants_enabled = false           # Disable password grant
  implicit_flow_enabled        = false           # Disable implicit flow
  service_accounts_enabled     = true            # Enable Client Credentials

  client_secret = random_password.client_secret[each.key].result

  access_token_lifespan = tostring(each.value.token_settings.access_token_lifespan)
}
```
- **access_type = "CONFIDENTIAL":** Requires client_secret for authentication
- **service_accounts_enabled = true:** Enables Client Credentials flow
- **All other flows disabled:** M2M only uses client credentials

**Step 5: Assign Service Account Roles**
```hcl
resource "keycloak_openid_client_service_account_role" "m2m_role" {
  for_each = {
    for pair in flatten([
      for client_key, client in local.clients : [
        for role in client.service_account_roles : {
          client_key = client_key
          role       = role
          unique_key = "${client_key}-${role}"
        }
      ]
    ]) : pair.unique_key => pair
  }

  realm_id                = local.config.realm
  client_id               = keycloak_openid_client.m2m[each.value.client_key].id
  service_account_user_id = keycloak_openid_client.m2m[each.value.client_key].service_account_user_id
  role                    = each.value.role
}
```
- **Purpose:** Grant permissions to the M2M service account
- **Flattened structure:** Handles multiple roles per client
- **Service account user:** Each M2M client gets a service account in Keycloak

#### 3. **outputs.tf** - Retrieve Client Information

```hcl
output "m2m_clients" {
  description = "All M2M clients configuration"
  value = {
    for key, client in keycloak_openid_client.m2m : key => {
      client_id               = random_uuid.client[key].result
      client_name             = client.name
      client_type             = "CONFIDENTIAL"
      flow_type               = "Client Credentials"
      service_account_user_id = client.service_account_user_id
      token_url               = "${var.keycloak_url}/realms/${local.config.realm}/protocol/openid-connect/token"
      grant_type              = "client_credentials"
    }
  }
  sensitive = true  # Hide from terminal output
}

output "m2m_client_secrets" {
  description = "Client secrets for M2M applications"
  value = {
    for key, _ in local.clients : key => random_password.client_secret[key].result
  }
  sensitive = true  # Secrets never shown in logs
}
```

## 🚀 Usage

### 1. Configure Your M2M Clients

Edit `apps.yaml` to add/modify M2M clients:

```yaml
realm: customer

clients:
  - client_id: my-backend-service
    name: My Backend Service
    description: Backend API authentication
    enabled: true
    
    token_settings:
      access_token_lifespan: 3600  # 1 hour
    
    service_account_roles:
      - view-users
      - manage-clients
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

#### Get All M2M Clients and Secrets

```bash
# View all client information (client_id/UUID)
terraform output -json m2m_clients | jq

# View all client secrets
terraform output -json m2m_client_secrets | jq
```

#### Get Specific Client Credentials

```bash
# Get client UUID
terraform output -json m2m_clients | jq -r '.["backend-service-m2m"].client_id'

# Get client secret
terraform output -json m2m_client_secrets | jq -r '.["backend-service-m2m"]'

# Get both together
echo "Client ID: $(terraform output -json m2m_clients | jq -r '.["backend-service-m2m"].client_id')"
echo "Client Secret: $(terraform output -json m2m_client_secrets | jq -r '.["backend-service-m2m"]')"
```

#### Get All Client Credentials in Table Format

```bash
# List all clients with their UUIDs
terraform output -json m2m_clients | jq -r 'to_entries[] | "\(.key): \(.value.client_id)"'

# Get credentials for all clients
for client in $(terraform output -json m2m_clients | jq -r 'keys[]'); do
  echo "=== $client ==="
  echo "Client ID: $(terraform output -json m2m_clients | jq -r ".\"$client\".client_id")"
  echo "Secret: $(terraform output -json m2m_client_secrets | jq -r ".\"$client\"")"
  echo ""
done
```

### 4. Test Client Credentials Flow

```bash
# Store credentials in variables
CLIENT_ID=$(terraform output -json m2m_clients | jq -r '.["backend-service-m2m"].client_id')
CLIENT_SECRET=$(terraform output -json m2m_client_secrets | jq -r '.["backend-service-m2m"]')
TOKEN_URL=$(terraform output -json m2m_clients | jq -r '.["backend-service-m2m"].token_url')

# Get access token
curl -X POST "$TOKEN_URL" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=openid" | jq
```

## 🔐 Client Credentials Flow Explained

### How It Works

```
Service/Application
    ↓
1. POST /token with client_id + client_secret
    ↓
Keycloak verifies credentials
    ↓
2. If valid → returns access_token
    ↓
3. Service uses access_token to call APIs
```

### Detailed Flow

```bash
# Step 1: Service authenticates to Keycloak
POST http://localhost:8080/realms/customer/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
client_id=<CLIENT_UUID>
client_secret=<48_CHAR_SECRET>
scope=openid

# Step 2: Keycloak responds with tokens
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 3600,
  "token_type": "Bearer",
  "scope": "openid"
}

# Step 3: Service uses access_token to call protected APIs
GET https://api.example.com/protected-resource
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Token Claims

The access token contains:
- **sub**: Service account user ID
- **azp**: Client ID (UUID)
- **iss**: Keycloak issuer URL
- **exp**: Token expiration timestamp
- **iat**: Token issued at timestamp
- **scope**: Granted scopes
- **realm_access.roles**: Assigned service account roles

## 📊 Example Implementations

### cURL Example

```bash
#!/bin/bash

CLIENT_ID="529d24ed-e037-3929-7c3f-78b5acd70804"
CLIENT_SECRET="your-48-char-secret-here"
TOKEN_URL="http://localhost:8080/realms/customer/protocol/openid-connect/token"

# Get access token
RESPONSE=$(curl -s -X POST "$TOKEN_URL" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=openid")

ACCESS_TOKEN=$(echo $RESPONSE | jq -r '.access_token')

echo "Access Token: $ACCESS_TOKEN"

# Use token to call API
curl -X GET "https://api.example.com/resource" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### Node.js Example

```javascript
const axios = require('axios');

const CLIENT_ID = '529d24ed-e037-3929-7c3f-78b5acd70804';
const CLIENT_SECRET = 'your-48-char-secret-here';
const TOKEN_URL = 'http://localhost:8080/realms/customer/protocol/openid-connect/token';

async function getAccessToken() {
  const params = new URLSearchParams();
  params.append('grant_type', 'client_credentials');
  params.append('client_id', CLIENT_ID);
  params.append('client_secret', CLIENT_SECRET);
  params.append('scope', 'openid');

  try {
    const response = await axios.post(TOKEN_URL, params, {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    });
    
    return response.data.access_token;
  } catch (error) {
    console.error('Error getting token:', error.response.data);
    throw error;
  }
}

async function callProtectedAPI(accessToken) {
  try {
    const response = await axios.get('https://api.example.com/resource', {
      headers: { 'Authorization': `Bearer ${accessToken}` }
    });
    
    return response.data;
  } catch (error) {
    console.error('API call failed:', error.response.data);
    throw error;
  }
}

// Usage
(async () => {
  const token = await getAccessToken();
  console.log('Access Token:', token);
  
  const data = await callProtectedAPI(token);
  console.log('API Response:', data);
})();
```

### Python Example

```python
import requests
from requests.auth import HTTPBasicAuth

CLIENT_ID = "529d24ed-e037-3929-7c3f-78b5acd70804"
CLIENT_SECRET = "your-48-char-secret-here"
TOKEN_URL = "http://localhost:8080/realms/customer/protocol/openid-connect/token"

def get_access_token():
    """Get access token using client credentials"""
    data = {
        'grant_type': 'client_credentials',
        'client_id': CLIENT_ID,
        'client_secret': CLIENT_SECRET,
        'scope': 'openid'
    }
    
    response = requests.post(
        TOKEN_URL,
        data=data,
        headers={'Content-Type': 'application/x-www-form-urlencoded'}
    )
    
    response.raise_for_status()
    return response.json()['access_token']

def call_protected_api(access_token):
    """Call protected API with access token"""
    headers = {'Authorization': f'Bearer {access_token}'}
    response = requests.get('https://api.example.com/resource', headers=headers)
    response.raise_for_status()
    return response.json()

# Usage
if __name__ == '__main__':
    token = get_access_token()
    print(f'Access Token: {token}')
    
    data = call_protected_api(token)
    print(f'API Response: {data}')
```

### Java Spring Boot Example

```java
import org.springframework.http.*;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

public class M2MAuthService {
    
    private static final String CLIENT_ID = "529d24ed-e037-3929-7c3f-78b5acd70804";
    private static final String CLIENT_SECRET = "your-48-char-secret-here";
    private static final String TOKEN_URL = "http://localhost:8080/realms/customer/protocol/openid-connect/token";
    
    private final RestTemplate restTemplate = new RestTemplate();
    
    public String getAccessToken() {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_FORM_URLENCODED);
        
        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        body.add("grant_type", "client_credentials");
        body.add("client_id", CLIENT_ID);
        body.add("client_secret", CLIENT_SECRET);
        body.add("scope", "openid");
        
        HttpEntity<MultiValueMap<String, String>> request = new HttpEntity<>(body, headers);
        
        ResponseEntity<TokenResponse> response = restTemplate.exchange(
            TOKEN_URL,
            HttpMethod.POST,
            request,
            TokenResponse.class
        );
        
        return response.getBody().getAccessToken();
    }
    
    public <T> T callProtectedAPI(String endpoint, Class<T> responseType) {
        String accessToken = getAccessToken();
        
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(accessToken);
        
        HttpEntity<Void> request = new HttpEntity<>(headers);
        
        ResponseEntity<T> response = restTemplate.exchange(
            endpoint,
            HttpMethod.GET,
            request,
            responseType
        );
        
        return response.getBody();
    }
    
    // Token Response DTO
    private static class TokenResponse {
        private String access_token;
        private int expires_in;
        
        // Getters and setters
        public String getAccessToken() { return access_token; }
        public void setAccessToken(String access_token) { this.access_token = access_token; }
        public int getExpiresIn() { return expires_in; }
        public void setExpiresIn(int expires_in) { this.expires_in = expires_in; }
    }
}
```

## 🔧 Configuration Options

### Token Lifespans

| Setting | Typical Value | Range | Description |
|---------|--------------|-------|-------------|
| `access_token_lifespan` | 3600s (1h) | 300-7200s | How long access token is valid |

**Recommendations:**
- Short-lived services: 300-600s (5-10 minutes)
- Long-running services: 3600-7200s (1-2 hours)
- Batch jobs: 1800-3600s (30-60 minutes)

### Service Account Roles

Grant permissions to the service account by listing realm roles:

```yaml
service_account_roles:
  - view-users          # Read user information
  - manage-users        # Create/update/delete users
  - view-clients        # Read client configurations
  - manage-clients      # Manage OAuth clients
  - view-realm          # Read realm settings
  - query-groups        # Query group information
```

**To view available roles in your realm:**
```bash
# List all realm roles
curl -H "Authorization: Bearer <ADMIN_TOKEN>" \
  http://localhost:8080/admin/realms/customer/roles | jq
```

## 📝 Adding Multiple M2M Clients

Simply add more entries to the `clients` array in `apps.yaml`:

```yaml
clients:
  - client_id: backend-service-m2m
    name: Backend Service
    enabled: true
    token_settings:
      access_token_lifespan: 3600
    service_account_roles: []
    
  - client_id: api-gateway-m2m
    name: API Gateway
    enabled: true
    token_settings:
      access_token_lifespan: 1800
    service_account_roles:
      - view-users
      - query-groups
    
  - client_id: batch-processor-m2m
    name: Batch Processor
    enabled: true
    token_settings:
      access_token_lifespan: 7200
    service_account_roles:
      - view-realm
```

Each client will get:
- Unique UUID as client_id
- Unique 48-character client_secret
- Independent token settings
- Independent service account roles

## 🔍 Troubleshooting

### Issue: "Invalid client credentials"
**Cause:** Wrong client_id or client_secret  
**Solution:** Verify credentials using `terraform output`
```bash
terraform output -json m2m_clients | jq -r '.["backend-service-m2m"].client_id'
terraform output -json m2m_client_secrets | jq -r '.["backend-service-m2m"]'
```

### Issue: "Client secret keeps changing"
**Cause:** Keepers not properly configured (shouldn't happen)  
**Solution:** Check that `client_id` in YAML is stable and not changing

### Issue: "Access token expired"
**Cause:** Token lifespan too short for your use case  
**Solution:** Increase `access_token_lifespan` in `token_settings`

### Issue: "Insufficient permissions"
**Cause:** Service account doesn't have required roles  
**Solution:** Add appropriate roles to `service_account_roles` array

### Issue: "Can't see client secret"
**Cause:** Outputs are marked as sensitive  
**Solution:** Use `-json` flag: `terraform output -json m2m_client_secrets`

## 🛡️ Security Best Practices

1. ✅ **Store secrets securely**
   - Use environment variables
   - Use secrets managers (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault)
   - Never hardcode in source code
   - Never commit to Git

2. ✅ **Rotate secrets periodically**
   - Change client_id in YAML to trigger new secret generation
   - Update all services with new credentials
   - Consider automated rotation

3. ✅ **Limit token lifespan**
   - Keep access tokens short-lived (1-2 hours max)
   - Implement token refresh logic if needed

4. ✅ **Use least privilege**
   - Only grant necessary service account roles
   - Review roles periodically

5. ✅ **Monitor and audit**
   - Log token requests
   - Monitor for unusual patterns
   - Set up alerts for failed auth attempts

6. ✅ **Network security**
   - Use HTTPS in production
   - Implement IP whitelisting if possible
   - Use mutual TLS for extra security

7. ⚠️ **Never expose secrets**
   - Don't log client secrets
   - Don't include in error messages
   - Don't send over unencrypted channels

## 📚 References

- [RFC 6749 Section 4.4 - Client Credentials Grant](https://datatracker.ietf.org/doc/html/rfc6749#section-4.4)
- [OAuth 2.0 Client Credentials Grant](https://oauth.net/2/grant-types/client-credentials/)
- [Keycloak Service Accounts](https://www.keycloak.org/docs/latest/server_admin/#_service_accounts)
- [Keycloak Terraform Provider](https://registry.terraform.io/providers/keycloak/keycloak/latest/docs)
