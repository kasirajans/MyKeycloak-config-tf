# Keycloak Configuration Deployment Guide

## Overview

This guide walks through deploying the complete Keycloak configuration including:
1. Custom client scopes
2. M2M clients with token exchange
3. AIAgent for Okta API integration

## Architecture

```
┌─────────────────────────────────────────────────┐
│          Keycloak Realm: customer               │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │  Custom Scopes (app/scopes)              │  │
│  │  ├─ user-profile                         │  │
│  │  ├─ user-roles                           │  │
│  │  ├─ organization                         │  │
│  │  ├─ api-permissions                      │  │
│  │  ├─ audit-info                           │  │
│  │  └─ okta-api-access ◄─── New for AIAgent│  │
│  └─────────────┬────────────────────────────┘  │
│                │ Referenced by                  │
│                ▼                                │
│  ┌──────────────────────────────────────────┐  │
│  │  M2M Clients (app/m2m)                   │  │
│  │  ├─ backend-service-m2m                  │  │
│  │  ├─ api-gateway-m2m (token exchange)     │  │
│  │  ├─ microservice-a-m2m                   │  │
│  │  └─ aiagent-okta-m2m ◄─── New           │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## Prerequisites

- Terraform >= 1.0
- Keycloak instance running (localhost:8080 or remote)
- Keycloak admin credentials
- Git (for version control)

## Step-by-Step Deployment

### Step 1: Clone and Review Configuration

```bash
cd d:/homelab/MyKeycloak-config-tf

# Review the structure
tree app/
# app/
# ├── scopes/
# │   ├── scopes.yaml
# │   ├── main.tf
# │   ├── variables.tf
# │   └── outputs.tf
# └── m2m/
#     ├── apps.yaml
#     ├── main.tf
#     ├── variables.tf
#     └── outputs.tf
```

### Step 2: Configure Scopes Module

```bash
cd app/scopes

# 1. Edit scopes.yaml - Update Okta domain
nano scopes.yaml
```

**Find and update:**
```yaml
# Line ~248: Update your Okta domain
- name: okta-domain
  config:
    claim.value: your-okta-domain.okta.com  # ← Change this
```

**Change to:**
```yaml
claim.value: dev-12345.okta.com  # Your actual Okta domain
```

```bash
# 2. Set up Terraform variables
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Update with your Keycloak credentials:**
```hcl
keycloak_url          = "http://localhost:8080"  # Or your Keycloak URL
keycloak_client_id    = "admin-cli"
keycloak_username     = "admin"
keycloak_password     = "your-admin-password"
keycloak_admin_realm  = "master"
```

### Step 3: Deploy Scopes Module

```bash
# Still in app/scopes directory

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Expected output:
# Plan: 6 scopes + ~30 protocol mappers to add
```

**Review carefully:**
- ✅ 6 client scopes to be created
- ✅ okta-api-access scope included
- ✅ All protocol mappers configured

```bash
# Apply configuration
terraform apply

# Type 'yes' when prompted
```

**Verify deployment:**
```bash
# Check created scopes
terraform output scope_names

# Expected:
# [
#   "api-permissions",
#   "audit-info",
#   "okta-api-access",    ← Should be here
#   "organization",
#   "user-profile",
#   "user-roles"
# ]

# View detailed scope information
terraform output scopes

# Check mapper statistics
terraform output mapper_counts
```

### Step 4: Configure M2M Module

```bash
cd ../m2m

# 1. Review apps.yaml (already configured with scopes)
cat apps.yaml | grep -A 5 "aiagent-okta-m2m"

# Should show:
#   - client_id: aiagent-okta-m2m
#     name: AIAgent - Okta Integration (M2M)
#     default_scopes:
#       - okta-api-access

# 2. Set up Terraform variables (same as scopes module)
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Use same Keycloak credentials as Step 2**

### Step 5: Deploy M2M Module

```bash
# Still in app/m2m directory

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Expected output:
# Plan: 4 clients + scope attachments + token exchange resources to add
```

**Review carefully:**
- ✅ 4 M2M clients to be created
- ✅ aiagent-okta-m2m client included
- ✅ Scope attachments for all clients
- ✅ Token exchange permissions for api-gateway-m2m

```bash
# Apply configuration
terraform apply

# Type 'yes' when prompted
```

**Verify deployment:**
```bash
# Check created clients
terraform output -json m2m_clients | jq 'keys'

# Expected:
# [
#   "aiagent-okta-m2m",      ← Should be here
#   "api-gateway-m2m",
#   "backend-service-m2m",
#   "microservice-a-m2m"
# ]

# Get AIAgent client details
terraform output -json m2m_clients | jq '.["aiagent-okta-m2m"]'
```

### Step 6: Retrieve AIAgent Credentials

```bash
# Get AIAgent client UUID
AIAGENT_CLIENT_ID=$(terraform output -json m2m_clients | jq -r '.["aiagent-okta-m2m"].client_id')

# Get AIAgent client secret
AIAGENT_CLIENT_SECRET=$(terraform output -json m2m_client_secrets | jq -r '.["aiagent-okta-m2m"]')

echo "========================================="
echo "AIAgent Credentials"
echo "========================================="
echo "Client ID: $AIAGENT_CLIENT_ID"
echo "Client Secret: $AIAGENT_CLIENT_SECRET"
echo "========================================="
```

**⚠️ IMPORTANT: Save these credentials securely!**

```bash
# Option 1: Save to environment file (for development)
cat > aiagent.env <<EOF
export KEYCLOAK_URL="http://localhost:8080"
export KEYCLOAK_REALM="customer"
export AIAGENT_CLIENT_ID="$AIAGENT_CLIENT_ID"
export AIAGENT_CLIENT_SECRET="$AIAGENT_CLIENT_SECRET"
EOF

# Option 2: Save to secrets manager (for production)
# AWS Secrets Manager
aws secretsmanager create-secret \
  --name aiagent/keycloak \
  --secret-string "{\"client_id\":\"$AIAGENT_CLIENT_ID\",\"client_secret\":\"$AIAGENT_CLIENT_SECRET\"}"

# Azure Key Vault
az keyvault secret set \
  --vault-name myvault \
  --name aiagent-client-id \
  --value "$AIAGENT_CLIENT_ID"
```

### Step 7: Test AIAgent Authentication

```bash
# Source the environment file
source aiagent.env

# Test token request
curl -X POST "$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$AIAGENT_CLIENT_ID" \
  -d "client_secret=$AIAGENT_CLIENT_SECRET" \
  -d "scope=okta-api-access" | jq .
```

**Expected response:**
```json
{
  "access_token": "eyJhbGc...",
  "token_type": "Bearer",
  "expires_in": 1800,
  "scope": "okta-api-access user-profile audit-info"
}
```

### Step 8: Verify Token Claims

```bash
# Get token
ACCESS_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/$KEYCLOAK_REALM/protocol/openid-connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=$AIAGENT_CLIENT_ID" \
  -d "client_secret=$AIAGENT_CLIENT_SECRET" \
  -d "scope=okta-api-access" | jq -r '.access_token')

# Decode and verify claims
echo $ACCESS_TOKEN | cut -d. -f2 | base64 -d | jq .
```

**Verify these claims exist:**
```json
{
  "okta_scopes": ["okta.users.read", "okta.users.manage", ...],
  "okta_domain": "dev-12345.okta.com",
  "agent_id": "ai-agent-okta-integration",
  "integration_type": "okta_user_management",
  "okta_api_version": "v1",
  "aud": ["okta-api"]
}
```

## Verification Checklist

### Scopes Module

- [ ] 6 scopes created
- [ ] okta-api-access scope exists
- [ ] Protocol mappers attached to scopes
- [ ] Mapper count matches expected (~30 mappers)

```bash
cd app/scopes
terraform output scope_names | grep okta-api-access
terraform output mapper_counts
```

### M2M Module

- [ ] 4 M2M clients created
- [ ] aiagent-okta-m2m client exists
- [ ] Scopes attached to clients
- [ ] Token exchange enabled for api-gateway-m2m

```bash
cd app/m2m
terraform output -json m2m_clients | jq 'keys'
terraform output exchange_enabled_clients
```

### Integration Test

- [ ] AIAgent can request token
- [ ] Token includes okta_scopes claim
- [ ] Token includes okta_domain claim
- [ ] Token includes agent_id claim
- [ ] Token expiry is 1800 seconds (30 min)

```bash
# Full integration test
./test-aiagent-integration.sh
```

## Troubleshooting

### Issue 1: Scopes not found in M2M module

**Error:**
```
Error: data.keycloak_openid_client_scope.custom_scopes["okta-api-access"]: Scope not found
```

**Solution:**
1. Verify scopes module deployed: `cd app/scopes && terraform output scope_names`
2. Check scope exists in Keycloak: Admin UI → Client Scopes
3. Redeploy M2M module: `cd app/m2m && terraform destroy && terraform apply`

### Issue 2: Token missing okta_scopes claim

**Error:** Token doesn't include `okta_scopes` claim

**Solution:**
1. Check scope attached: `terraform output -json m2m_clients | jq '.["aiagent-okta-m2m"]'`
2. Request scope explicitly: Add `scope=okta-api-access` to token request
3. Verify mapper configuration in scopes module

### Issue 3: Invalid credentials error

**Error:** `401 Unauthorized` when requesting token

**Solution:**
1. Verify client ID: `echo $AIAGENT_CLIENT_ID`
2. Re-retrieve secret: `terraform output -json m2m_client_secrets | jq -r '.["aiagent-okta-m2m"]'`
3. Check Keycloak URL and realm name

### Issue 4: Token exchange validation errors

**Error:** Validation preconditions failing

**Solution:**
1. Check token exchange section in apps.yaml
2. Verify api-gateway-m2m has `capabilities.token_exchange_enabled: true`
3. Redeploy: `terraform apply`

## Rollback Procedure

### Rollback M2M Module Only

```bash
cd app/m2m
terraform destroy -target=keycloak_openid_client.m2m["aiagent-okta-m2m"]
```

### Rollback Scopes Module Only

```bash
cd app/scopes
terraform destroy -target=keycloak_openid_client_scope.scope["okta-api-access"]
```

### Complete Rollback

```bash
# Destroy M2M module first (depends on scopes)
cd app/m2m
terraform destroy

# Then destroy scopes module
cd ../scopes
terraform destroy
```

## Updating Configuration

### Update Okta Domain

```bash
cd app/scopes

# 1. Edit scopes.yaml
nano scopes.yaml
# Update claim.value for okta-domain mapper

# 2. Apply changes
terraform apply

# 3. Verify
cd ../m2m
terraform apply  # May need to reapply M2M to pick up changes
```

### Add New M2M Client

```bash
cd app/m2m

# 1. Edit apps.yaml
nano apps.yaml
# Add new client configuration

# 2. Apply changes
terraform apply

# 3. Get new client credentials
terraform output -json m2m_client_secrets | jq -r '.["new-client-id"]'
```

### Add New Scope

```bash
cd app/scopes

# 1. Edit scopes.yaml
nano scopes.yaml
# Add new scope definition

# 2. Apply changes
terraform apply

# 3. Update M2M clients to use new scope
cd ../m2m
nano apps.yaml
# Add scope to client's default_scopes or optional_scopes

# 4. Apply M2M changes
terraform apply
```

## Production Deployment

### Best Practices

1. **Use Remote State**
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "keycloak/scopes/terraform.tfstate"
    region = "us-east-1"
  }
}
```

2. **Use Workspaces**
```bash
# Development
terraform workspace new dev
terraform apply

# Production
terraform workspace new prod
terraform apply
```

3. **Use CI/CD**
```yaml
# .github/workflows/deploy.yml
name: Deploy Keycloak Config

on:
  push:
    branches: [main]

jobs:
  deploy-scopes:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy Scopes
        run: |
          cd app/scopes
          terraform init
          terraform apply -auto-approve

  deploy-m2m:
    needs: deploy-scopes
    runs-on: ubuntu-latest
    steps:
      - name: Deploy M2M
        run: |
          cd app/m2m
          terraform init
          terraform apply -auto-approve
```

4. **Secure Secrets**
- Never commit `terraform.tfvars`
- Use encrypted variables in CI/CD
- Store client secrets in secrets manager
- Rotate credentials regularly

## Monitoring

### Terraform State

```bash
# Check state
terraform show

# List resources
terraform state list

# View specific resource
terraform state show keycloak_openid_client.m2m[\"aiagent-okta-m2m\"]
```

### Keycloak Admin UI

1. Navigate to: `http://localhost:8080/admin`
2. Realm: `customer`
3. Check:
   - Client Scopes → Should show all custom scopes
   - Clients → Should show all M2M clients
   - Click client → Client Scopes tab → Verify attachments

## Next Steps

1. **Configure AIAgent Application**
   - See [AIAGENT_OKTA_INTEGRATION.md](AIAGENT_OKTA_INTEGRATION.md)
   - Implement token retrieval in your AIAgent code
   - Test Okta API integration

2. **Set Up Monitoring**
   - Track token requests
   - Monitor Okta API calls
   - Alert on failures

3. **Documentation**
   - Document your Okta domain
   - Update scope permissions as needed
   - Maintain runbooks for common operations

## Support

- **Scopes Module**: [app/scopes/README.md](app/scopes/README.md)
- **M2M Module**: [app/m2m/README.md](app/m2m/README.md) (if exists)
- **AIAgent Integration**: [AIAGENT_OKTA_INTEGRATION.md](AIAGENT_OKTA_INTEGRATION.md)
- **Issues**: Create GitHub issue or contact team
