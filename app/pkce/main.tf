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
  
  # Get unique authentication flows referenced by clients
  authentication_flows = toset(compact([
    for client_key, client in local.clients : 
    lookup(lookup(client, "authentication_flow", {}), "browser_flow", null)
  ]))
  
  # Flatten mappers for easier processing
  user_attribute_mappers = flatten([
    for client_key, client in local.clients : [
      for mapper in lookup(client, "mappers", []) : {
        client_key      = client_key
        mapper_key      = "${client_key}-${mapper.name}"
        name            = mapper.name
        user_attribute  = mapper.user_attribute
        claim_name      = mapper.claim_name
      } if lookup(mapper, "type", "") == "user_attribute"
    ]
  ])
  
  audience_mappers = flatten([
    for client_key, client in local.clients : [
      for mapper in lookup(client, "mappers", []) : {
        client_key               = client_key
        mapper_key               = "${client_key}-${mapper.name}"
        name                     = mapper.name
        included_client_audience = lookup(mapper, "audience", "self") == "self" ? random_uuid.client[client_key].result : mapper.audience
      } if lookup(mapper, "type", "") == "audience"
    ]
  ])
}

# Dynamically reference authentication flows from YAML configuration
data "keycloak_authentication_flow" "flows" {
  for_each = local.authentication_flows
  
  realm_id = local.config.realm
  alias    = each.value
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
  
  # Additional client attributes for CORS headers
  extra_config = {
    "access.token.signed.response.alg" = "RS256"
    "cors.allowed.headers" = "Accept,Authorization,Cache-Control,Content-Type,DNT,If-Modified-Since,Keep-Alive,Origin,User-Agent,X-Requested-With,ngrok-skip-browser-warning"
  }
  
  # Post-logout redirect URIs for Single Logout (SLO)
  valid_post_logout_redirect_uris = lookup(each.value, "valid_post_logout_redirect_uris", [])

  # Token settings
  access_token_lifespan       = tostring(each.value.token_settings.access_token_lifespan)
  client_session_idle_timeout = tostring(each.value.token_settings.session_idle_timeout)
  client_session_max_lifespan = tostring(each.value.token_settings.session_max_lifespan)

  # Consent settings
  consent_required = each.value.consent_required

  # Authentication Flow Binding - Dynamically use flow from YAML
  dynamic "authentication_flow_binding_overrides" {
    for_each = lookup(each.value, "authentication_flow", null) != null ? [1] : []
    content {
      browser_id = data.keycloak_authentication_flow.flows[each.value.authentication_flow.browser_flow].id
    }
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

# User Attribute Protocol Mappers (configured from YAML)
resource "keycloak_openid_user_attribute_protocol_mapper" "mapper" {
  for_each = { for m in local.user_attribute_mappers : m.mapper_key => m }

  realm_id            = local.config.realm
  client_id           = keycloak_openid_client.pkce[each.value.client_key].id
  name                = each.value.name
  user_attribute      = each.value.user_attribute
  claim_name          = each.value.claim_name
  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

# Audience Protocol Mappers (configured from YAML)
resource "keycloak_openid_audience_protocol_mapper" "mapper" {
  for_each = { for m in local.audience_mappers : m.mapper_key => m }

  realm_id                 = local.config.realm
  client_id                = keycloak_openid_client.pkce[each.value.client_key].id
  name                     = each.value.name
  included_client_audience = each.value.included_client_audience
  add_to_id_token          = true
  add_to_access_token      = true
}

# Legacy audience mapper (kept for backward compatibility)
resource "keycloak_openid_audience_protocol_mapper" "pkce_audience" {
  for_each = { for k, v in local.clients : k => v if length(lookup(v, "mappers", [])) == 0 }

  realm_id  = local.config.realm
  client_id = keycloak_openid_client.pkce[each.key].id
  name      = "audience-mapper"

  included_client_audience = keycloak_openid_client.pkce[each.key].client_id
  add_to_id_token          = true
  add_to_access_token      = true
}
