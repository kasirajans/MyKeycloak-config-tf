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

# Read AIAgent configuration from YAML file
locals {
  config = yamldecode(file("${path.module}/apps.yaml"))

  # Allowed service types (extend this list as needed)
  allowed_service_types = ["MCP"]

  # Validate service types
  validated_clients = [
    for client in local.config.clients : client
    if contains(local.allowed_service_types, client.service_type)
  ]

  # Check for invalid service types and fail with clear error message
  invalid_service_types = [
    for client in local.config.clients : client.service_type
    if !contains(local.allowed_service_types, client.service_type)
  ]

  # This will cause terraform to fail if invalid service types are found
  validation_check = length(local.invalid_service_types) == 0 ? true : tobool("Invalid service_type found: ${join(", ", local.invalid_service_types)}. Allowed values: ${join(", ", local.allowed_service_types)}")

  # Transform clients with standardized naming and description
  clients = {
    for client in local.validated_clients : "aiagent_${client.service_type}_${client.app_name}" => {
      app_name     = client.app_name
      service_type = client.service_type
      client_id    = "aiagent_${client.service_type}_${client.app_name}"
      name         = "AIAgent-${client.service_type}-${client.app_name}"
      description  = "${client.owner};${client.team};${client.email}"
      scope        = client.scope
    }
  }

  # Get unique scopes from all clients
  unique_scopes = toset([for client in local.clients : client.scope])
}

# Data source to fetch custom scopes from scopes module
data "keycloak_openid_client_scope" "custom_scopes" {
  for_each = local.unique_scopes

  realm_id = local.config.realm
  name     = each.value
}

# Generate stable UUIDs for each AIAgent client
resource "random_uuid" "client" {
  for_each = local.clients

  keepers = {
    client_id = each.value.client_id
  }
}

# Generate secure random client secret for each AIAgent client (48 characters)
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

# AIAgent M2M Clients - Client Credentials Flow Only
# All settings hardcoded for consistency
resource "keycloak_openid_client" "aiagent" {
  for_each = local.clients

  lifecycle {
    ignore_changes = [name]
  }

  realm_id    = local.config.realm
  client_id   = random_uuid.client[each.key].result
  name        = each.value.name
  description = each.value.description
  enabled     = true  # Hardcoded: always enabled

  # Hardcoded: Client Credentials flow only
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = false
  direct_access_grants_enabled = false
  implicit_flow_enabled        = false
  service_accounts_enabled     = true

  # Use generated random password
  client_secret = random_password.client_secret[each.key].result

  # Hardcoded: Token settings (30 minutes)
  access_token_lifespan = "1800"
}

# Create custom client scope for each AIAgent client
resource "keycloak_openid_client_scope" "aiagent_scope" {
  for_each = local.clients

  realm_id               = local.config.realm
  name                   = "${each.value.client_id}-scope"
  description            = "Custom scope for ${each.value.name}"
  include_in_token_scope = true

  gui_order = 1
}

# Add audience mapper for each AIAgent client
resource "keycloak_openid_audience_protocol_mapper" "aiagent_audience" {
  for_each = local.clients

  realm_id  = local.config.realm
  client_id = keycloak_openid_client.aiagent[each.key].id
  name      = "audience-mapper"

  included_client_audience = keycloak_openid_client.aiagent[each.key].client_id
  add_to_id_token          = true
  add_to_access_token      = true
}

# Attach scopes to clients as default scopes
# For M2M service accounts, only include the custom scope (no email/profile)
# These are service-to-service calls, not user-facing
resource "keycloak_openid_client_default_scopes" "aiagent_scopes" {
  for_each = local.clients

  realm_id  = local.config.realm
  client_id = keycloak_openid_client.aiagent[each.key].id

  default_scopes = [
    data.keycloak_openid_client_scope.custom_scopes[each.value.scope].name
  ]
}
