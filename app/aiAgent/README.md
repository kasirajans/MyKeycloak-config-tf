# AIAgent Clients Module

Specialized module for creating standardized M2M clients for AI Agents with enforced naming and hardcoded security settings.

## 📋 Overview

✅ **Enforced Naming**: `aiagent_<ServiceType>_<AppName>`
✅ **Service Type Validation**: Only allowed types (currently: MCP)
✅ **Structured Description**: `<AppOwner>;<TeamName>;<TeamEmailID>`
✅ **Hardcoded Settings**: Consistent security configuration
✅ **Client Credentials Only**: Service-to-service authentication
✅ **Single Scope**: Each agent gets exactly one default scope  

## 🚀 Quick Start

1. Deploy scopes: `cd ../scopes && terraform apply`
2. Edit `apps.yaml` with your AI agent configuration
3. Deploy: `terraform apply`
4. Get credentials: `terraform output aiagent_summary`

## ⚙️ Configuration (apps.yaml)

```yaml
realm: AIAgent

clients:
  - app_name: oktaAPI
    service_type: MCP  # Required: Only MCP allowed currently
    owner: Kraaj
    team: Identity Platform
    email: identity-platform@company.com
    scope: okta-api-access
```

## Flow Diagram

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Agent as AI Agent
    participant MCP as MCP Server
    participant IdP as IdP Auth Server
    participant RAS as Resource Auth Server
    participant API as Resource API

    rect rgb(241, 239, 232)
        Note over User,IdP: Phase 1 — User triggers agent + SSO
        User->>Agent: Assign task
        Agent->>IdP: SSO login (OIDC on behalf of user)
        IdP-->>Agent: ID Token + Refresh Token
    end

    rect rgb(250, 238, 218)
        Note over Agent,IdP: Phase 2 — Token exchange (RFC 8693)
        Agent->>IdP: POST /token grant_type=token-exchange<br/>subject_token=<id_token> aud=resource-as
        IdP-->>Agent: ID-JAG (typ=oauth-id-jag+jwt)
    end

    rect rgb(230, 241, 251)
        Note over Agent,RAS: Phase 3 — Present ID-JAG, get access token (RFC 7523)
        Agent->>RAS: POST /token grant_type=jwt-bearer<br/>assertion=<id_jag>
        RAS-->>Agent: Access Token
    end

    rect rgb(250, 236, 231)
        Note over Agent,MCP: Phase 4 — Agent registers token with MCP server
        Agent->>MCP: Register access token
        MCP-->>Agent: Token stored, tools ready
    end

    rect rgb(238, 237, 254)
        Note over Agent,MCP: Phase 5 — MCP server gets scoped token (optional)
        Agent->>MCP: Scoped token for MCP server
        MCP-->>Agent: Ready to call tools
    end

    loop For each tool call
        rect rgb(241, 239, 232)
            Note over User,API: Runtime — MCP tool execution loop
            User->>Agent: User goal / prompt
            Agent-->>User: Agent decides: call MCP tool

            Agent->>MCP: tools/call {name, args}<br/>(MCP protocol over SSE / stdio)
            MCP->>API: GET /api/resource<br/>Authorization: Bearer <token>
            API-->>MCP: 200 OK — resource data
            MCP-->>Agent: Tool result (structured JSON)

            Agent->>Agent: Reason over result
            Agent-->>User: Final answer to user
        end
    end
```
## 🔒 Hardcoded Settings

- Client ID: `aiagent_<ServiceType>_<AppName>` (enforced)
- Display Name: `AIAgent-<ServiceType>-<AppName>` (enforced)
- Description: `<Owner>;<Team>;<Email>` (enforced)
- Grant Type: Client Credentials only
- Token Lifespan: 30 minutes (1800s)
- Enabled: Always true
- Client Secret: Auto-generated 48 characters
- Scope: Default (not optional)

## 🔍 Outputs

```bash
# Summary
terraform output aiagent_summary

# Full config
terraform output -json aiagent_clients | jq '.["aiagent_MCP_oktaAPI"]'

# Secret
terraform output -json aiagent_client_secrets | jq -r '.["aiagent_MCP_oktaAPI"]'
```

## 🧪 Testing Client Credentials

### Option 1: Automated Setup (Recommended)

Run the helper script to extract credentials and populate test files:

```bash
./update-test-credentials.sh aiagent_MCP_oktaAPI
```

This will:
- Update `.env` with client credentials
- Update `test.http` with the same credentials
- Display a ready-to-use cURL command

### Option 2: REST Client (VS Code)

1. Install the **REST Client** extension in VS Code
2. Open `test.http`
3. Click "Send Request" above the POST request
4. View the access token in the response

### Option 3: Test Script (Recommended for cURL)

```bash
./test-token.sh
```

This script properly handles special characters in the client secret and displays a formatted response.

### Option 4: Manual cURL

```bash
source .env
curl -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "client_secret=$CLIENT_SECRET" \
  --data-urlencode "scope=$SCOPE"
```

**Note:** Use `--data-urlencode` instead of `-d` to properly handle special characters in the client secret.

## 📝 Service Type Validation

Client naming convention: `aiagent_<ServiceType>_<AppName>`

- Currently allowed: `MCP`
- To add more types: Edit `allowed_service_types` in `main.tf`
- Invalid types will fail during terraform plan with a clear error

See full documentation in the main app README.


