#!/bin/bash
# Test token endpoint with client credentials

set -e

# Load from .env
source .env

echo "Testing token endpoint..."
echo "Client ID: $CLIENT_ID"
echo "Keycloak URL: $KEYCLOAK_URL"
echo "Realm: $REALM"
echo ""

# Make the request with proper URL encoding
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST \
  "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode "client_secret=${CLIENT_SECRET}" \
  --data-urlencode "scope=${SCOPE}")

# Extract HTTP code and body
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

echo "HTTP Status: $HTTP_CODE"
echo ""
echo "Response:"
echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
