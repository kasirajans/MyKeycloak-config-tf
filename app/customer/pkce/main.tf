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

# Read apps configuration from YAML file
locals {
  config  = yamldecode(file("${path.module}/apps.yaml"))
  clients = { for idx, client in local.config.clients : client.client_id => client }
}

# Generate stable UUIDs for each PKCE client
resource "random_uuid" "client" {
  for_each = local.clients
  
  keepers = {
    client_id = each.value.client_id
  }
}

# PKCE Clients - Authorization Code Flow with PKCE (for Web/Mobile Apps)
resource "keycloak_openid_client" "pkce" {
  for_each = local.clients
  
  lifecycle {
    ignore_changes = [name]
  }

  realm_id  = local.config.realm
  client_id = random_uuid.client[each.key].result
  name      = each.value.name
  enabled   = each.value.enabled

  access_type           = "PUBLIC"  # Public client for PKCE
  standard_flow_enabled = true      # Authorization Code Flow
  direct_access_grants_enabled = false
  implicit_flow_enabled = false
  service_accounts_enabled = false

  # PKCE Configuration
  pkce_code_challenge_method = each.value.pkce.challenge_method

  valid_redirect_uris = each.value.redirect_uris
  web_origins         = each.value.web_origins

  # Token settings
  access_token_lifespan       = tostring(each.value.token_settings.access_token_lifespan)
  client_session_idle_timeout = tostring(each.value.token_settings.session_idle_timeout)
  client_session_max_lifespan = tostring(each.value.token_settings.session_max_lifespan)

  # Consent settings
  consent_required = each.value.consent_required

  # Authentication Flow Binding - Use MFA flow
  authentication_flow_binding_overrides {
    browser_id = data.keycloak_authentication_flow.mfa_browser.id
  }
}

# Create custom client scope for each PKCE client
resource "keycloak_openid_client_scope" "pkce_scope" {
  for_each = local.clients

  realm_id               = local.config.realm
  name                   = "${each.value.client_id}-scope"
  description            = "Custom scope for ${each.value.name}"
  include_in_token_scope = true

  gui_order = 1
}

# Add audience mapper for each PKCE client
resource "keycloak_openid_audience_protocol_mapper" "pkce_audience" {
  for_each = local.clients

  realm_id  = local.config.realm
  client_id = keycloak_openid_client.pkce[each.key].id
  name      = "audience-mapper"

  included_client_audience = keycloak_openid_client.pkce[each.key].client_id
  add_to_id_token          = true
  add_to_access_token      = true
}
