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

# Read IdP configuration from YAML file
locals {
  config    = yamldecode(file("${path.module}/idpprovider.yml"))
  providers = { for idx, provider in local.config.providers : provider.alias => provider }

  # Filter OIDC providers
  oidc_providers = { for k, v in local.providers : k => v if v.provider_type == "oidc" }
}

# Configure OIDC Identity Providers in AIAgent realm for token exchange
resource "keycloak_oidc_identity_provider" "providers" {
  for_each = local.oidc_providers

  realm = local.config.realm
  alias = each.value.alias

  # Display settings
  display_name         = each.value.display_name
  enabled              = each.value.enabled
  store_token          = each.value.settings.store_token
  add_read_token_role_on_create = false
  trust_email          = each.value.settings.trust_email
  hide_on_login_page   = each.value.settings.hide_on_login_page
  gui_order            = try(each.value.settings.gui_order, null)

  # OIDC Configuration
  authorization_url = each.value.oidc.authorization_url
  token_url        = each.value.oidc.token_url
  logout_url       = each.value.oidc.logout_url
  user_info_url    = each.value.oidc.user_info_url
  jwks_url         = each.value.oidc.jwks_url

  # Client credentials (optional for token exchange via JWKS)
  # Only needed if Keycloak calls Okta userinfo endpoint
  # For pure token exchange validation, leave empty
  client_id     = each.value.oidc.client_id
  client_secret = try(each.value.oidc.client_secret, null) != null ? each.value.oidc.client_secret : ""

  # Token validation - critical for token exchange
  validate_signature   = try(each.value.settings.validate_signature, true)

  # Scopes (include okta-specific scopes for user data access)
  default_scopes = each.value.oidc.default_scopes

  # Sync settings - FORCE will update user info on each token exchange
  sync_mode = each.value.settings.sync_mode

  # First broker login flow
  first_broker_login_flow_alias = try(each.value.settings.first_broker_login_flow_alias, "first broker login")

  # Additional settings for token exchange support
  accepts_prompt_none_forward_from_client = false
  disable_user_info                       = false
  backchannel_supported                   = true
  link_only                               = try(each.value.settings.link_only, false)
}

# Create a flat map of all mappers for all providers (for reference/documentation)
locals {
  # Documentation: OIDC attribute mappers can be configured via:
  # 1. Keycloak Admin Console (Clients → okta-oidc → Mappers tab)
  # 2. Keycloak REST API
  # Not directly supported in Terraform provider v5
  
  mapper_tuples = flatten([
    for provider_key, provider in local.oidc_providers : [
      for mapper in provider.mappers : {
        key            = "${provider_key}-${mapper.name}"
        provider_alias = provider.alias
        mapper         = mapper
      }
    ]
  ])

  # Convert to map for reference
  all_mappers = { for item in local.mapper_tuples : item.key => item }
}

# Note: OIDC Attribute Mappers must be configured manually or via REST API
# because keycloak provider v5 doesn't support keycloak_oidc_identity_provider_mapper
#
# To add mappers manually in Keycloak Admin Console:
# 1. Go to Identity Providers → okta-oidc → Mappers tab
# 2. Click "Create" and add mappers for each claim
#
# Mappers to add:
# - sub → sub (INHERIT)
# - email → email (INHERIT)
# - given_name → firstName (INHERIT)
# - family_name → lastName (INHERIT)
# - preferred_username → username (INHERIT)
# - appRoles → appRoles (INHERIT)
# - groups → groups (INHERIT)
# - iss → okta_domain (INHERIT)
