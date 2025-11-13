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

# Generate stable UUIDs for each Password Grant client
resource "random_uuid" "client" {
  for_each = local.clients
  
  keepers = {
    client_id = each.value.client_id
  }
}

# Generate secure random client secret for CONFIDENTIAL clients only
resource "random_password" "client_secret" {
  for_each = {
    for key, client in local.clients : key => client
    if try(client.access_type, "CONFIDENTIAL") == "CONFIDENTIAL"
  }
  
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
    client_id = each.value.client_id
  }
}

# Password Grant Clients - Resource Owner Password Credentials Flow
resource "keycloak_openid_client" "password_grant" {
  for_each = local.clients
  
  lifecycle {
    ignore_changes = [name]
  }

  realm_id  = local.config.realm
  client_id = random_uuid.client[each.key].result
  name      = each.value.name
  enabled   = each.value.enabled

  # Access type: PUBLIC for native apps, CONFIDENTIAL for server-side apps
  access_type = try(each.value.access_type, "CONFIDENTIAL")
  
  # Enable ROPC (Resource Owner Password Credentials) flow
  standard_flow_enabled        = false
  direct_access_grants_enabled = true   # This enables Password Grant flow
  implicit_flow_enabled        = false
  service_accounts_enabled     = false

  # Client secret only for CONFIDENTIAL clients
  client_secret = try(each.value.access_type, "CONFIDENTIAL") == "CONFIDENTIAL" ? random_password.client_secret[each.key].result : null

  # Token settings
  access_token_lifespan       = tostring(each.value.token_settings.access_token_lifespan)
  client_session_idle_timeout = tostring(each.value.token_settings.session_idle_timeout)
  client_session_max_lifespan = tostring(each.value.token_settings.session_max_lifespan)

  # Refresh token settings
  client_offline_session_idle_timeout = tostring(try(each.value.token_settings.refresh_token_lifespan, 1800))

  # Consent settings
  consent_required = each.value.consent_required
}

# Create custom client scope for each Password Grant client
resource "keycloak_openid_client_scope" "password_scope" {
  for_each = local.clients

  realm_id               = local.config.realm
  name                   = "${each.value.client_id}-scope"
  description            = "Custom scope for ${each.value.name}"
  include_in_token_scope = true

  gui_order = 1
}

# Add audience mapper for each Password Grant client
resource "keycloak_openid_audience_protocol_mapper" "password_audience" {
  for_each = local.clients

  realm_id  = local.config.realm
  client_id = keycloak_openid_client.password_grant[each.key].id
  name      = "audience-mapper"

  included_client_audience = keycloak_openid_client.password_grant[each.key].client_id
  add_to_id_token          = true
  add_to_access_token      = true
}
