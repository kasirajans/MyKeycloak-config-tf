terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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

# Read app configuration from YAML file
locals {
  app_config = yamldecode(file("${path.module}/app.yaml"))
  
  pkce_config = local.app_config.pkce_client
  m2m_config  = local.app_config.m2m_client
}

# Generate stable UUIDs for resource identification
# These will persist across runs and prevent resource recreation
resource "random_uuid" "pkce_client" {
  keepers = {
    client_id = local.pkce_config.client_id
  }
}

resource "random_uuid" "m2m_client" {
  keepers = {
    client_id = local.m2m_config.client_id
  }
}

# Generate secure random client secret for M2M client
resource "random_password" "m2m_client_secret" {
  length  = 48
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
    client_id = local.m2m_config.client_id
  }
}

# PKCE Client - Authorization Code Flow with PKCE (for Web/Mobile Apps)
resource "keycloak_openid_client" "pkce_client" {
  lifecycle {
    ignore_changes = [name]
  }

  realm_id  = local.app_config.realm
  client_id = random_uuid.pkce_client.result
  name      = local.pkce_config.name
  enabled   = local.pkce_config.enabled

  access_type           = "PUBLIC"  # Public client for PKCE
  standard_flow_enabled = local.pkce_config.flows.standard_flow
  direct_access_grants_enabled = local.pkce_config.flows.direct_access_grants
  implicit_flow_enabled = local.pkce_config.flows.implicit_flow
  service_accounts_enabled = local.pkce_config.flows.service_accounts

  # PKCE Configuration
  pkce_code_challenge_method = local.pkce_config.pkce.challenge_method

  valid_redirect_uris = local.pkce_config.redirect_uris
  web_origins         = local.pkce_config.web_origins

  # Token settings
  access_token_lifespan               = tostring(local.pkce_config.token_settings.access_token_lifespan)
  client_session_idle_timeout         = tostring(local.pkce_config.token_settings.session_idle_timeout)
  client_session_max_lifespan         = tostring(local.pkce_config.token_settings.session_max_lifespan)

  # Consent settings
  consent_required = local.pkce_config.consent_required
}

# M2M Client - Client Credentials Flow (for Service-to-Service)
resource "keycloak_openid_client" "m2m_client" {
  lifecycle {
    ignore_changes = [name]
  }

  realm_id  = local.app_config.realm
  client_id = random_uuid.m2m_client.result
  name      = local.m2m_config.name
  enabled   = local.m2m_config.enabled

  access_type                  = "CONFIDENTIAL"  # Confidential client for M2M
  standard_flow_enabled        = local.m2m_config.flows.standard_flow
  direct_access_grants_enabled = local.m2m_config.flows.direct_access_grants
  implicit_flow_enabled        = local.m2m_config.flows.implicit_flow
  service_accounts_enabled     = local.m2m_config.flows.service_accounts

  # Use generated random password instead of hardcoded secret
  client_secret = random_password.m2m_client_secret.result

  # Token settings
  access_token_lifespan = tostring(local.m2m_config.token_settings.access_token_lifespan)
}

# Create custom client scope for PKCE client (optional)
resource "keycloak_openid_client_scope" "pkce_custom_scope" {
  realm_id               = local.app_config.realm
  name                   = "${local.pkce_config.client_id}-scope"
  description            = "Custom scope for ${local.pkce_config.name}"
  include_in_token_scope = true

  gui_order = 1
}

# Add custom claims to PKCE client scope (optional)
resource "keycloak_openid_user_attribute_protocol_mapper" "pkce_user_attribute" {
  realm_id        = local.app_config.realm
  client_scope_id = keycloak_openid_client_scope.pkce_custom_scope.id
  name            = "user-groups-mapper"

  user_attribute = "groups"
  claim_name     = "groups"
  claim_value_type = "String"
}

# Add custom client scope for M2M client (optional)
resource "keycloak_openid_client_scope" "m2m_custom_scope" {
  realm_id               = local.app_config.realm
  name                   = "${local.m2m_config.client_id}-scope"
  description            = "Custom scope for ${local.m2m_config.name}"
  include_in_token_scope = true

  gui_order = 1
}

# Assign roles to M2M service account (optional)
resource "keycloak_openid_client_service_account_role" "m2m_realm_role" {
  count = length(local.m2m_config.service_account_roles)

  realm_id                = local.app_config.realm
  client_id               = keycloak_openid_client.m2m_client.id
  service_account_user_id = keycloak_openid_client.m2m_client.service_account_user_id
  role                    = local.m2m_config.service_account_roles[count.index]
}

# Optional: Create audience mapper for PKCE client
resource "keycloak_openid_audience_protocol_mapper" "pkce_audience_mapper" {
  realm_id  = local.app_config.realm
  client_id = keycloak_openid_client.pkce_client.id
  name      = "audience-mapper"

  included_client_audience = keycloak_openid_client.pkce_client.client_id
  add_to_id_token          = local.app_config.mappers.audience_mapper.add_to_id_token
  add_to_access_token      = local.app_config.mappers.audience_mapper.add_to_access_token
}

# Optional: Create audience mapper for M2M client
resource "keycloak_openid_audience_protocol_mapper" "m2m_audience_mapper" {
  realm_id  = local.app_config.realm
  client_id = keycloak_openid_client.m2m_client.id
  name      = "audience-mapper"

  included_client_audience = keycloak_openid_client.m2m_client.client_id
  add_to_id_token          = local.app_config.mappers.audience_mapper.add_to_id_token
  add_to_access_token      = local.app_config.mappers.audience_mapper.add_to_access_token
}
