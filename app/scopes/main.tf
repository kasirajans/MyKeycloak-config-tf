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

# Read scopes configuration from YAML file
locals {
  config = yamldecode(file("${path.module}/scopes.yaml"))
  scopes = { for idx, scope in local.config.scopes : scope.name => scope }

  # Flatten mappers for each scope
  scope_mappers = flatten([
    for scope_name, scope in local.scopes : [
      for mapper in try(scope.mappers, []) : {
        scope_name  = scope_name
        mapper_name = mapper.name
        mapper      = mapper
        unique_key  = "${scope_name}-${mapper.name}"
      }
    ]
  ])

  # Convert flattened mappers to map
  mappers_map = { for mapper in local.scope_mappers : mapper.unique_key => mapper }
}

# Create custom client scopes
resource "keycloak_openid_client_scope" "scope" {
  for_each = local.scopes

  realm_id               = local.config.realm
  name                   = each.value.name
  description            = each.value.description
  include_in_token_scope = try(each.value.include_in_token_scope, true)

  # Consent screen settings
  consent_screen_text = try(each.value.consent_screen_text, "")
  gui_order           = try(each.value.gui_order, 0)
}

# ============================================================================
# Protocol Mappers
# ============================================================================

# User Property Mappers (username, email, etc.)
resource "keycloak_openid_user_property_protocol_mapper" "user_property" {
  for_each = {
    for k, v in local.mappers_map : k => v
    if v.mapper.protocol_mapper == "oidc-usermodel-property-mapper"
  }

  realm_id            = local.config.realm
  client_scope_id     = keycloak_openid_client_scope.scope[each.value.scope_name].id
  name                = each.value.mapper_name
  claim_name          = each.value.mapper.config["claim.name"]
  user_property       = each.value.mapper.config["user.attribute"]
  add_to_id_token     = try(each.value.mapper.config["id.token.claim"], true)
  add_to_access_token = try(each.value.mapper.config["access.token.claim"], true)
  add_to_userinfo     = try(each.value.mapper.config["userinfo.token.claim"], true)
}

# User Attribute Mappers (custom user attributes)
resource "keycloak_openid_user_attribute_protocol_mapper" "user_attribute" {
  for_each = {
    for k, v in local.mappers_map : k => v
    if v.mapper.protocol_mapper == "oidc-usermodel-attribute-mapper"
  }

  realm_id            = local.config.realm
  client_scope_id     = keycloak_openid_client_scope.scope[each.value.scope_name].id
  name                = each.value.mapper_name
  claim_name          = each.value.mapper.config["claim.name"]
  user_attribute      = each.value.mapper.config["user.attribute"]
  add_to_id_token     = try(each.value.mapper.config["id.token.claim"], true)
  add_to_access_token = try(each.value.mapper.config["access.token.claim"], true)
  add_to_userinfo     = try(each.value.mapper.config["userinfo.token.claim"], true)
}

# Full Name Mapper
resource "keycloak_openid_full_name_protocol_mapper" "full_name" {
  for_each = {
    for k, v in local.mappers_map : k => v
    if v.mapper.protocol_mapper == "oidc-full-name-mapper"
  }

  realm_id            = local.config.realm
  client_scope_id     = keycloak_openid_client_scope.scope[each.value.scope_name].id
  name                = each.value.mapper_name
  add_to_id_token     = try(each.value.mapper.config["id.token.claim"], true)
  add_to_access_token = try(each.value.mapper.config["access.token.claim"], true)
  add_to_userinfo     = try(each.value.mapper.config["userinfo.token.claim"], true)
}

# Hardcoded Claim Mappers
resource "keycloak_openid_hardcoded_claim_protocol_mapper" "hardcoded" {
  for_each = {
    for k, v in local.mappers_map : k => v
    if v.mapper.protocol_mapper == "oidc-hardcoded-claim-mapper"
  }

  realm_id            = local.config.realm
  client_scope_id     = keycloak_openid_client_scope.scope[each.value.scope_name].id
  name                = each.value.mapper_name
  claim_name          = each.value.mapper.config["claim.name"]
  claim_value         = each.value.mapper.config["claim.value"]
  claim_value_type    = try(each.value.mapper.config["jsonType.label"], "String")
  add_to_id_token     = try(each.value.mapper.config["id.token.claim"], true)
  add_to_access_token = try(each.value.mapper.config["access.token.claim"], true)
  add_to_userinfo     = try(each.value.mapper.config["userinfo.token.claim"], false)
}

# User Realm Role Mappers
resource "keycloak_openid_user_realm_role_protocol_mapper" "realm_roles" {
  for_each = {
    for k, v in local.mappers_map : k => v
    if v.mapper.protocol_mapper == "oidc-usermodel-realm-role-mapper"
  }

  realm_id            = local.config.realm
  client_scope_id     = keycloak_openid_client_scope.scope[each.value.scope_name].id
  name                = each.value.mapper_name
  claim_name          = each.value.mapper.config["claim.name"]
  multivalued         = try(each.value.mapper.config["multivalued"], true)
  add_to_id_token     = try(each.value.mapper.config["id.token.claim"], false)
  add_to_access_token = try(each.value.mapper.config["access.token.claim"], true)
  add_to_userinfo     = try(each.value.mapper.config["userinfo.token.claim"], false)
}

# User Client Role Mappers
resource "keycloak_openid_user_client_role_protocol_mapper" "client_roles" {
  for_each = {
    for k, v in local.mappers_map : k => v
    if v.mapper.protocol_mapper == "oidc-usermodel-client-role-mapper"
  }

  realm_id            = local.config.realm
  client_scope_id     = keycloak_openid_client_scope.scope[each.value.scope_name].id
  name                = each.value.mapper_name
  claim_name          = each.value.mapper.config["claim.name"]
  multivalued         = try(each.value.mapper.config["multivalued"], true)
  add_to_id_token     = try(each.value.mapper.config["id.token.claim"], false)
  add_to_access_token = try(each.value.mapper.config["access.token.claim"], true)
  add_to_userinfo     = try(each.value.mapper.config["userinfo.token.claim"], false)

  # Note: client_id_for_role_mappings can be set if needed
  # client_id_for_role_mappings = "some-client-id"
}

# Audience Mappers
resource "keycloak_openid_audience_protocol_mapper" "audience" {
  for_each = {
    for k, v in local.mappers_map : k => v
    if v.mapper.protocol_mapper == "oidc-audience-mapper"
  }

  realm_id        = local.config.realm
  client_scope_id = keycloak_openid_client_scope.scope[each.value.scope_name].id
  name            = each.value.mapper_name

  included_custom_audience = try(each.value.mapper.config["included.custom.audience"], "")
  add_to_id_token          = try(each.value.mapper.config["id.token.claim"], false)
  add_to_access_token      = try(each.value.mapper.config["access.token.claim"], true)
}

# User Session Note Mappers
resource "keycloak_openid_user_session_note_protocol_mapper" "session_note" {
  for_each = {
    for k, v in local.mappers_map : k => v
    if v.mapper.protocol_mapper == "oidc-usersessionmodel-note-mapper"
  }

  realm_id            = local.config.realm
  client_scope_id     = keycloak_openid_client_scope.scope[each.value.scope_name].id
  name                = each.value.mapper_name
  claim_name          = each.value.mapper.config["claim.name"]
  session_note        = each.value.mapper.config["user.session.note"]
  claim_value_type    = try(each.value.mapper.config["jsonType.label"], "String")
  add_to_id_token     = try(each.value.mapper.config["id.token.claim"], true)
  add_to_access_token = try(each.value.mapper.config["access.token.claim"], true)
}
