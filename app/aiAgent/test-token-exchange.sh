#!/bin/bash
# Test token exchange endpoint (RFC 8693)
# Exchanges an Okta IdToken for a Keycloak access token

set -e

# Load from .env
source .env

# Token exchange specific variables (can be overridden)
SUBJECT_TOKEN_TYPE="${SUBJECT_TOKEN_TYPE:-urn:ietf:params:oauth:token-type:access_token}"
REQUESTED_TOKEN_TYPE="${REQUESTED_TOKEN_TYPE:-urn:ietf:params:oauth:token-type:access_token}"
AUDIENCE="${AUDIENCE:-resource-a-server}"

# Client credentials for token exchange (AgentResource type)
# Use the generated AgentResource client ID and secret
TOKEN_EXCHANGE_CLIENT_ID="${TOKEN_EXCHANGE_CLIENT_ID:-}"
TOKEN_EXCHANGE_CLIENT_SECRET="${TOKEN_EXCHANGE_CLIENT_SECRET:-}"

# Okta access token - use access_token from Okta, not id_token
# To get Okta access token:
#   POST https://your-okta-domain/oauth2/v1/token
#   grant_type=client_credentials&client_id=...&client_secret=...&scope=...
IDP_ID_TOKEN="${IDP_ID_TOKEN:-}"

echo "Testing token exchange endpoint (RFC 8693)..."
echo "Keycloak URL: $KEYCLOAK_URL"
echo "Realm: $REALM"
echo "Grant Type: urn:ietf:params:oauth:grant-type:token-exchange"
echo "Audience: $AUDIENCE"
echo "Scope: ${SCOPE:-pd:user:read}"
echo ""

# Validate required variables
if [ -z "$TOKEN_EXCHANGE_CLIENT_ID" ] || [ -z "$TOKEN_EXCHANGE_CLIENT_SECRET" ]; then
  echo "ERROR: TOKEN_EXCHANGE_CLIENT_ID and TOKEN_EXCHANGE_CLIENT_SECRET must be set in .env"
  echo "  These are the AgentResource client credentials (not MCP credentials)"
  exit 1
fi

if [ -z "$IDP_ID_TOKEN" ]; then
  echo "WARNING: IDP_ID_TOKEN not set in .env"
  echo "  To get an Okta access token:"
  echo "  1. Use client credentials flow: curl -X POST 'https://your-okta-domain/oauth2/v1/token'"
  echo "     -d 'grant_type=client_credentials&client_id=...&client_secret=...&scope=...'"
  echo "  2. Extract the access_token from the response"
  echo "  3. Set IDP_ID_TOKEN environment variable in .env"
  echo ""
  echo "  For testing, using a placeholder (will fail at Keycloak validation)"
  IDP_ID_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1cmk6dXNlcjp0ZXN0LXVzZXIiLCJuYW1lIjoiVGVzdCBVc2VyIiwiaWF0IjoxNTE2MjM5MDIyfQ.placeholder"
  echo "  Using placeholder token: ${IDP_ID_TOKEN:0:50}..."
  echo ""
fi

# Make the token exchange request
echo "Sending token exchange request..."
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST \
  "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" \
  --data-urlencode "client_id=${TOKEN_EXCHANGE_CLIENT_ID}" \
  --data-urlencode "client_secret=${TOKEN_EXCHANGE_CLIENT_SECRET}" \
  --data-urlencode "subject_token=${IDP_ID_TOKEN}" \
  --data-urlencode "subject_token_type=${SUBJECT_TOKEN_TYPE}" \
  --data-urlencode "requested_token_type=${REQUESTED_TOKEN_TYPE}" \
  --data-urlencode "audience=${AUDIENCE}" \
  --data-urlencode "scope=${SCOPE:-pd:user:read}")

# Extract HTTP code and body
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

echo "HTTP Status: $HTTP_CODE"
echo ""

# Parse and display response
if command -v jq &> /dev/null; then
  echo "Response:"
  echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
  
  # If successful, extract and decode the access token
  if [ "$HTTP_CODE" = "200" ]; then
    echo ""
    echo "Access Token (decoded):"
    ACCESS_TOKEN=$(echo "$BODY" | jq -r '.access_token')
    echo "$ACCESS_TOKEN" | jq -R 'split(".") | .[1] | @base64d | fromjson' 2>/dev/null || echo "Could not decode token"
  fi
else
  echo "Response:"
  echo "$BODY"
fi

exit 0
