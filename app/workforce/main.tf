terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5"
    }
  }
}

provider "keycloak" {
  client_id = var.keycloak_client_id
  url       = var.keycloak_url
  username  = var.keycloak_username
  password  = var.keycloak_password
  realm     = var.keycloak_admin_realm
}

# PKCE Client - Authorization Code Flow with PKCE (for Web/Mobile Apps)
resource "keycloak_openid_client" "pkce_client" {
  realm_id  = var.keycloak_realm
  client_id = var.pkce_client_id
  name      = var.pkce_client_name
  enabled   = true

  access_type           = "public"  # Public client for PKCE
  standard_flow_enabled = true      # Enable Authorization Code Flow
  direct_access_grants_enabled = false
  implicit_flow_enabled = false
  service_accounts_enabled = false

  # PKCE Configuration
  pkce_code_challenge_method = "S256"

  valid_redirect_uris = var.pkce_redirect_uris
  web_origins         = var.pkce_web_origins

  # Token settings
  access_token_lifespan               = var.access_token_lifespan
  client_session_idle_timeout         = var.session_idle_timeout
  client_session_max_lifespan         = var.session_max_lifespan

  # Consent settings
  consent_required = false

  # Optional: Add custom client scopes
  extra_config = {
    "backchannel.logout.session.required" = "true"
    "backchannel.logout.revoke.offline.tokens" = "false"
  }
}

# M2M Client - Client Credentials Flow (for Service-to-Service)
resource "keycloak_openid_client" "m2m_client" {
  realm_id  = var.keycloak_realm
  client_id = var.m2m_client_id
  name      = var.m2m_client_name
  enabled   = true

  access_type                  = "confidential"  # Confidential client for M2M
  standard_flow_enabled        = false
  direct_access_grants_enabled = false
  implicit_flow_enabled        = false
  service_accounts_enabled     = true  # Enable Service Account (Client Credentials)

  client_secret = var.m2m_client_secret

  # Valid redirect URIs (required even for M2M)
  valid_redirect_uris = ["*"]

  # Token settings
  access_token_lifespan = var.m2m_access_token_lifespan

  # Optional: Add custom client scopes
  extra_config = {
    "access.token.lifespan" = var.m2m_access_token_lifespan
  }
}

# Create custom client scope for PKCE client (optional)
resource "keycloak_openid_client_scope" "pkce_custom_scope" {
  realm_id               = var.keycloak_realm
  name                   = "${var.pkce_client_id}-scope"
  description            = "Custom scope for ${var.pkce_client_name}"
  include_in_token_scope = true

  gui_order = 1
}

# Add custom claims to PKCE client scope (optional)
resource "keycloak_openid_user_attribute_protocol_mapper" "pkce_user_attribute" {
  realm_id        = var.keycloak_realm
  client_scope_id = keycloak_openid_client_scope.pkce_custom_scope.id
  name            = "user-groups-mapper"

  user_attribute = "groups"
  claim_name     = "groups"
  claim_value_type = "String"
}

# Add custom client scope for M2M client (optional)
resource "keycloak_openid_client_scope" "m2m_custom_scope" {
  realm_id               = var.keycloak_realm
  name                   = "${var.m2m_client_id}-scope"
  description            = "Custom scope for ${var.m2m_client_name}"
  include_in_token_scope = true

  gui_order = 1
}

# Assign roles to M2M service account (optional)
resource "keycloak_openid_client_service_account_role" "m2m_realm_role" {
  count = length(var.m2m_service_account_roles)

  realm_id                = var.keycloak_realm
  service_account_user_id = keycloak_openid_client.m2m_client.service_account_user_id
  role                    = var.m2m_service_account_roles[count.index]
}

# Optional: Create audience mapper for PKCE client
resource "keycloak_openid_audience_protocol_mapper" "pkce_audience_mapper" {
  realm_id  = var.keycloak_realm
  client_id = keycloak_openid_client.pkce_client.id
  name      = "audience-mapper"

  included_client_audience = keycloak_openid_client.pkce_client.client_id
  add_to_id_token          = true
  add_to_access_token      = true
}

# Optional: Create audience mapper for M2M client
resource "keycloak_openid_audience_protocol_mapper" "m2m_audience_mapper" {
  realm_id  = var.keycloak_realm
  client_id = keycloak_openid_client.m2m_client.id
  name      = "audience-mapper"

  included_client_audience = keycloak_openid_client.m2m_client.client_id
  add_to_id_token          = true
  add_to_access_token      = true
}
