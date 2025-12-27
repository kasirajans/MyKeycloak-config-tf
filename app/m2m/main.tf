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

# Data source to fetch custom scopes from scopes module
# This allows referencing scopes created by the ../scopes module
data "keycloak_openid_client_scope" "custom_scopes" {
  for_each = toset(flatten([
    for client in yamldecode(file("${path.module}/apps.yaml")).clients :
    concat(
      try(client.default_scopes, []),
      try(client.optional_scopes, [])
    )
  ]))

  realm_id = yamldecode(file("${path.module}/apps.yaml")).realm
  name     = each.value
}

# Read apps configuration from YAML file
locals {
  config  = yamldecode(file("${path.module}/apps.yaml"))
  clients = { for idx, client in local.config.clients : client.client_id => client }

  # Clients with default scopes
  clients_with_default_scopes = {
    for k, v in local.clients : k => v
    if try(length(v.default_scopes), 0) > 0
  }

  # Clients with optional scopes
  clients_with_optional_scopes = {
    for k, v in local.clients : k => v
    if try(length(v.optional_scopes), 0) > 0
  }
}

# Generate stable UUIDs for each M2M client
resource "random_uuid" "client" {
  for_each = local.clients

  keepers = {
    client_id = each.value.client_id
  }
}

# Generate secure random client secret for each M2M client
resource "random_password" "client_secret" {
  for_each = local.clients

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

# M2M Clients - Client Credentials Flow (for Service-to-Service)
resource "keycloak_openid_client" "m2m" {
  for_each = local.clients

  lifecycle {
    ignore_changes = [name]
  }

  realm_id  = local.config.realm
  client_id = random_uuid.client[each.key].result
  name      = each.value.name
  enabled   = each.value.enabled

  access_type                  = "CONFIDENTIAL" # Confidential client for M2M
  standard_flow_enabled        = false
  direct_access_grants_enabled = false
  implicit_flow_enabled        = false
  service_accounts_enabled     = true # Enable Client Credentials Flow

  # Use generated random password
  client_secret = random_password.client_secret[each.key].result

  # Token settings
  access_token_lifespan = tostring(each.value.token_settings.access_token_lifespan)
}

# Create custom client scope for each M2M client
resource "keycloak_openid_client_scope" "m2m_scope" {
  for_each = local.clients

  realm_id               = local.config.realm
  name                   = "${each.value.client_id}-scope"
  description            = "Custom scope for ${each.value.name}"
  include_in_token_scope = true

  gui_order = 1
}

# Assign roles to M2M service accounts
resource "keycloak_openid_client_service_account_role" "m2m_role" {
  for_each = {
    for pair in flatten([
      for client_key, client in local.clients : [
        for role in client.service_account_roles : {
          client_key = client_key
          role       = role
          unique_key = "${client_key}-${role}"
        }
      ]
    ]) : pair.unique_key => pair
  }

  realm_id                = local.config.realm
  client_id               = keycloak_openid_client.m2m[each.value.client_key].id
  service_account_user_id = keycloak_openid_client.m2m[each.value.client_key].service_account_user_id
  role                    = each.value.role
}

# Add audience mapper for each M2M client
resource "keycloak_openid_audience_protocol_mapper" "m2m_audience" {
  for_each = local.clients

  realm_id  = local.config.realm
  client_id = keycloak_openid_client.m2m[each.key].id
  name      = "audience-mapper"

  included_client_audience = keycloak_openid_client.m2m[each.key].client_id
  add_to_id_token          = true
  add_to_access_token      = true
}

# ============================================================================
# Client Scope Attachments (from scopes module)
# ============================================================================

# Attach default scopes to clients
# resource "keycloak_openid_client_default_scopes" "default" {
#   for_each = local.clients_with_default_scopes

#   realm_id  = local.config.realm
#   client_id = keycloak_openid_client.m2m[each.key].id

#   default_scopes = concat(
#     [
#       "profile",
#       "email",
#       "roles",
#       "web-origins"
#     ],
#     [
#       for scope_name in try(each.value.default_scopes, []) :
#       data.keycloak_openid_client_scope.custom_scopes[scope_name].name
#     ]
#   )
# }

# Attach optional scopes to clients
resource "keycloak_openid_client_optional_scopes" "optional" {
  for_each = local.clients_with_optional_scopes

  realm_id  = local.config.realm
  client_id = keycloak_openid_client.m2m[each.key].id

  optional_scopes = [
    for scope_name in try(each.value.optional_scopes, []) :
    data.keycloak_openid_client_scope.custom_scopes[scope_name].name
  ]
}
