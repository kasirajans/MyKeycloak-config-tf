# AIAgent Okta API Integration Guide

## Overview

This guide explains how the AIAgent integrates with Okta API for user management operations using Keycloak OAuth 2.0 scopes and M2M (machine-to-machine) authentication.

## Architecture

```
┌──────────────┐
│   AIAgent    │
│  (Service)   │
└──────┬───────┘
       │
       │ 1. Request Access Token
       │    (client_credentials grant)
       ▼
┌──────────────────────────┐
│  Keycloak Auth Server    │
│  ┌────────────────────┐  │
│  │ aiagent-okta-m2m   │  │ ◄─── M2M Client
│  │ (Client)           │  │
│  └────────┬───────────┘  │
│           │              │
│           │ Attached     │
│           ▼              │
│  ┌────────────────────┐  │
│  │ okta-api-access    │  │ ◄─── Custom Scope
│  │ (Scope)            │  │
│  └────────────────────┘  │
└───────────┬──────────────┘
            │
            │ 2. Returns Access Token with:
            │    - okta_scopes: ["okta.users.read", "okta.users.manage", ...]
            │    - okta_domain: "your-okta-domain.okta.com"
            │    - agent_id: "ai-agent-okta-integration"
            ▼
┌──────────────────────────┐
│   AIAgent with Token     │
└───────────┬──────────────┘
            │
            │ 3. Call Okta API with Token
            │    Authorization: Bearer <access_token>
            ▼
┌──────────────────────────┐
│    Okta API              │
│  /api/v1/users           │
│  /api/v1/groups          │
└──────────────────────────┘
```

## Configuration Files

### 1. Scope Definition (scopes/scopes.yaml)

The `okta-api-access` scope is defined with the following mappers:

```yaml
- name: okta-api-access
  description: Okta API access for user management operations
  protocol: openid-connect
  include_in_token_scope: true

  mappers:
    # Okta API audience
    - name: okta-api-audience
      protocol_mapper: oidc-audience-mapper
      config:
        included.custom.audience: okta-api

    # Okta API scopes/permissions
    - name: okta-api-scopes
      protocol_mapper: oidc-hardcoded-claim-mapper
      config:
        claim.name: okta_scopes
        claim.value: '["okta.users.read", "okta.users.manage", "okta.groups.read", "okta.groups.manage"]'

    # AIAgent identifier
    - name: agent-identifier
      config:
        claim.name: agent_id
        claim.value: ai-agent-okta-integration

    # Okta domain
    - name: okta-domain
      config:
        claim.name: okta_domain
        claim.value: your-okta-domain.okta.com
```

**📝 Before deploying, update:**
- `okta_domain` with your actual Okta domain
- `okta_scopes` with required Okta API scopes

### 2. M2M Client Definition (m2m/apps.yaml)

The `aiagent-okta-m2m` client configuration:

```yaml
- client_id: aiagent-okta-m2m
  name: AIAgent - Okta Integration (M2M)
  description: AIAgent service account for Okta API user management
  enabled: true

  token_settings:
    access_token_lifespan: 1800  # 30 minutes

  default_scopes:
    - okta-api-access  # Primary scope
    - user-profile      # User context
    - audit-info        # Tracking

  optional_scopes:
    - organization      # Optional org context
```

## Deployment Steps

### Step 1: Deploy Scopes Module

```bash
cd app/scopes

# Update scopes.yaml with your Okta domain
nano scopes.yaml
# Find line with: claim.value: your-okta-domain.okta.com
# Replace with:   claim.value: dev-12345.okta.com

# Deploy scopes
terraform init
terraform plan
terraform apply
```

**Verify:**
```bash
terraform output scope_names
# Should include: okta-api-access
```

### Step 2: Deploy M2M Module

```bash
cd ../m2m

# Deploy M2M clients with scope attachments
terraform init
terraform plan
terraform apply
```

**Verify:**
```bash
terraform output m2m_clients
# Should show aiagent-okta-m2m client
```

### Step 3: Retrieve AIAgent Credentials

```bash
# Get client UUID
CLIENT_ID=$(terraform output -json m2m_clients | jq -r '.["aiagent-okta-m2m"].client_id')

# Get client secret
CLIENT_SECRET=$(terraform output -json m2m_client_secrets | jq -r '.["aiagent-okta-m2m"]')

echo "Client ID: $CLIENT_ID"
echo "Client Secret: $CLIENT_SECRET"
```

**⚠️ Security:** Store these credentials securely (environment variables, secrets manager, etc.)

## Usage

### 1. Request Access Token (AIAgent)

```bash
# Token endpoint
TOKEN_URL="http://keycloak.example.com/realms/customer/protocol/openid-connect/token"

# Request token
curl -X POST "$TOKEN_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=okta-api-access"
```

**Response:**
```json
{
  "access_token": "eyJhbGc...",
  "token_type": "Bearer",
  "expires_in": 1800,
  "scope": "okta-api-access user-profile audit-info"
}
```

### 2. Decode Access Token

```bash
ACCESS_TOKEN="eyJhbGc..."

# Decode JWT (payload)
echo $ACCESS_TOKEN | cut -d. -f2 | base64 -d | jq .
```

**Expected Claims:**
```json
{
  "exp": 1735128000,
  "iat": 1735126200,
  "sub": "service-account-aiagent-okta-m2m",
  "aud": ["okta-api"],
  "client_id": "uuid-of-aiagent-client",
  "scope": "okta-api-access user-profile audit-info",

  "okta_scopes": [
    "okta.users.read",
    "okta.users.manage",
    "okta.groups.read",
    "okta.groups.manage"
  ],
  "okta_domain": "dev-12345.okta.com",
  "agent_id": "ai-agent-okta-integration",
  "integration_type": "okta_user_management",
  "okta_api_version": "v1",
  "rate_limit_tier": "standard"
}
```

### 3. Call Okta API (AIAgent → Okta)

**Important:** The Keycloak access token is **NOT** used directly with Okta API. Instead, use it for authorization in your backend, then use Okta API token.

#### Option A: Backend Validates Keycloak Token, Uses Okta API Token

```python
# AIAgent backend service
import requests
from jose import jwt

# 1. AIAgent gets Keycloak token (shown above)
keycloak_token = get_keycloak_token()

# 2. Validate Keycloak token
claims = jwt.decode(keycloak_token, keycloak_public_key)

# 3. Check claims
if "okta-api-access" in claims.get("scope", ""):
    okta_domain = claims["okta_domain"]
    okta_scopes = claims["okta_scopes"]

    # 4. Use Okta API token (stored securely)
    okta_api_token = os.getenv("OKTA_API_TOKEN")

    # 5. Call Okta API
    response = requests.get(
        f"https://{okta_domain}/api/v1/users",
        headers={
            "Authorization": f"SSWS {okta_api_token}",
            "Accept": "application/json"
        }
    )
```

#### Option B: Token Exchange Pattern (Advanced)

If you implement token exchange:

```bash
# Exchange Keycloak token for Okta-compatible token
curl -X POST "$TOKEN_URL" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "subject_token=$KEYCLOAK_TOKEN" \
  -d "subject_token_type=urn:ietf:params:oauth:token-type:access_token" \
  -d "audience=okta-api"
```

## Token Claims Reference

| Claim | Type | Description | Example |
|-------|------|-------------|---------|
| `okta_scopes` | Array[String] | Okta API permissions | `["okta.users.read", "okta.users.manage"]` |
| `okta_domain` | String | Okta organization domain | `dev-12345.okta.com` |
| `agent_id` | String | AIAgent identifier | `ai-agent-okta-integration` |
| `integration_type` | String | Integration type | `okta_user_management` |
| `okta_api_version` | String | Okta API version | `v1` |
| `rate_limit_tier` | String | Rate limit tier | `standard` |
| `aud` | Array[String] | Audience | `["okta-api"]` |

## Okta API Scopes

Configure these scopes in [scopes.yaml](app/scopes/scopes.yaml) based on your needs:

### User Management
- `okta.users.read` - Read user information
- `okta.users.manage` - Create, update, delete users
- `okta.users.userprofile.manage` - Manage user profiles

### Group Management
- `okta.groups.read` - Read group information
- `okta.groups.manage` - Create, update, delete groups

### Application Management
- `okta.apps.read` - Read application configurations
- `okta.apps.manage` - Manage applications

### Custom Scopes
Add custom scopes as needed for your AIAgent use case.

## Security Best Practices

### 1. Token Lifespan
```yaml
token_settings:
  access_token_lifespan: 1800  # 30 minutes - shorter is better
```

### 2. Credential Storage
```bash
# Use environment variables
export KEYCLOAK_CLIENT_ID="uuid-from-terraform"
export KEYCLOAK_CLIENT_SECRET="secret-from-terraform"
export OKTA_API_TOKEN="okta-api-token"

# Or use secrets manager
aws secretsmanager get-secret-value --secret-id aiagent/keycloak
```

### 3. Scope Validation
```python
def validate_token(token):
    claims = jwt.decode(token, public_key)

    # Verify required claims
    assert "okta-api-access" in claims["scope"]
    assert claims["agent_id"] == "ai-agent-okta-integration"
    assert claims["okta_domain"] == EXPECTED_OKTA_DOMAIN

    return claims
```

### 4. Rate Limiting
Monitor the `rate_limit_tier` claim and implement rate limiting:

```python
rate_limits = {
    "standard": 1000,  # requests per minute
    "premium": 5000
}

tier = claims.get("rate_limit_tier", "standard")
max_requests = rate_limits[tier]
```

### 5. Audit Logging
The `audit-info` scope includes session tracking:

```python
# Log all Okta API calls
log.info({
    "agent_id": claims["agent_id"],
    "session_id": claims["sid"],
    "action": "okta_user_create",
    "okta_domain": claims["okta_domain"]
})
```

## Troubleshooting

### Token Not Including okta_scopes Claim

**Check:**
1. Scopes module deployed: `cd app/scopes && terraform output scope_names`
2. Scope attached to client: `cd app/m2m && terraform show | grep okta-api-access`
3. Scope requested in token request: `scope=okta-api-access`

**Debug:**
```bash
# Request token with verbose output
curl -v -X POST "$TOKEN_URL" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=okta-api-access" 2>&1 | grep -i scope
```

### Invalid Audience Error

**Fix:** Ensure `okta-api` is in the `aud` claim:
```bash
echo $TOKEN | cut -d. -f2 | base64 -d | jq .aud
# Should include: "okta-api"
```

### Okta API Returns 401 Unauthorized

**Check:**
1. Using Okta API token (not Keycloak token): `Authorization: SSWS {okta_api_token}`
2. Okta API token has correct scopes
3. Okta domain is correct

## Integration Examples

### Python Example

```python
import os
import requests
from jose import jwt

class AIAgentOktaClient:
    def __init__(self):
        self.keycloak_url = os.getenv("KEYCLOAK_URL")
        self.client_id = os.getenv("CLIENT_ID")
        self.client_secret = os.getenv("CLIENT_SECRET")
        self.okta_api_token = os.getenv("OKTA_API_TOKEN")
        self.keycloak_token = None

    def get_keycloak_token(self):
        """Get access token from Keycloak"""
        response = requests.post(
            f"{self.keycloak_url}/realms/customer/protocol/openid-connect/token",
            data={
                "grant_type": "client_credentials",
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "scope": "okta-api-access"
            }
        )
        response.raise_for_status()
        self.keycloak_token = response.json()["access_token"]
        return self.keycloak_token

    def get_okta_config(self):
        """Extract Okta config from Keycloak token"""
        claims = jwt.get_unverified_claims(self.keycloak_token)
        return {
            "domain": claims["okta_domain"],
            "scopes": claims["okta_scopes"],
            "agent_id": claims["agent_id"]
        }

    def list_okta_users(self):
        """List users via Okta API"""
        # Get Keycloak token for authorization
        self.get_keycloak_token()
        config = self.get_okta_config()

        # Call Okta API with Okta token
        response = requests.get(
            f"https://{config['domain']}/api/v1/users",
            headers={
                "Authorization": f"SSWS {self.okta_api_token}",
                "Accept": "application/json"
            }
        )
        response.raise_for_status()
        return response.json()

# Usage
client = AIAgentOktaClient()
users = client.list_okta_users()
```

### Node.js Example

```javascript
const axios = require('axios');
const jwt = require('jsonwebtoken');

class AIAgentOktaClient {
  constructor() {
    this.keycloakUrl = process.env.KEYCLOAK_URL;
    this.clientId = process.env.CLIENT_ID;
    this.clientSecret = process.env.CLIENT_SECRET;
    this.oktaApiToken = process.env.OKTA_API_TOKEN;
  }

  async getKeycloakToken() {
    const response = await axios.post(
      `${this.keycloakUrl}/realms/customer/protocol/openid-connect/token`,
      new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: this.clientId,
        client_secret: this.clientSecret,
        scope: 'okta-api-access'
      })
    );
    this.keycloakToken = response.data.access_token;
    return this.keycloakToken;
  }

  getOktaConfig() {
    const claims = jwt.decode(this.keycloakToken);
    return {
      domain: claims.okta_domain,
      scopes: claims.okta_scopes,
      agentId: claims.agent_id
    };
  }

  async listOktaUsers() {
    await this.getKeycloakToken();
    const config = this.getOktaConfig();

    const response = await axios.get(
      `https://${config.domain}/api/v1/users`,
      {
        headers: {
          'Authorization': `SSWS ${this.oktaApiToken}`,
          'Accept': 'application/json'
        }
      }
    );
    return response.data;
  }
}

// Usage
const client = new AIAgentOktaClient();
const users = await client.listOktaUsers();
```

## Monitoring and Observability

### Metrics to Track

1. **Token Requests**
   - Total requests
   - Success/failure rate
   - Token expiration events

2. **Okta API Calls**
   - Request count by endpoint
   - Response times
   - Error rates

3. **Rate Limiting**
   - Requests per minute
   - Rate limit tier usage
   - Throttled requests

### Example Monitoring Code

```python
from prometheus_client import Counter, Histogram

# Metrics
token_requests = Counter('aiagent_token_requests_total', 'Token requests', ['status'])
okta_api_calls = Counter('aiagent_okta_api_calls_total', 'Okta API calls', ['endpoint', 'status'])
okta_api_latency = Histogram('aiagent_okta_api_latency_seconds', 'Okta API latency')

def get_token_with_metrics():
    try:
        token = get_keycloak_token()
        token_requests.labels(status='success').inc()
        return token
    except Exception as e:
        token_requests.labels(status='error').inc()
        raise

@okta_api_latency.time()
def call_okta_api(endpoint):
    try:
        response = requests.get(endpoint)
        okta_api_calls.labels(endpoint=endpoint, status=response.status_code).inc()
        return response
    except Exception as e:
        okta_api_calls.labels(endpoint=endpoint, status='error').inc()
        raise
```

## References

- [Keycloak Client Scopes](https://www.keycloak.org/docs/latest/server_admin/#_client_scopes)
- [Okta API Documentation](https://developer.okta.com/docs/reference/)
- [OAuth 2.0 Client Credentials Grant](https://oauth.net/2/grant-types/client-credentials/)
- [RFC 8693 - OAuth 2.0 Token Exchange](https://datatracker.ietf.org/doc/html/rfc8693)
