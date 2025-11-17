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

# Configure OIDC Identity Providers in SP-Customer realm
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
  
  # Client credentials
  client_id     = each.value.oidc.client_id
  client_secret = try(each.value.oidc.client_secret, "")  # Empty string for PKCE public clients
  
  # Token validation
  validate_signature   = try(each.value.settings.validate_signature, true)
  
  # Scopes
  default_scopes = each.value.oidc.default_scopes
  
  # Sync settings
  sync_mode = each.value.settings.sync_mode
  
  # First broker login flow
  first_broker_login_flow_alias = try(each.value.settings.first_broker_login_flow_alias, "first broker login")
  
  # Additional settings
  accepts_prompt_none_forward_from_client = false
  disable_user_info                       = false
  backchannel_supported                   = true  # Enable backchannel logout with proper URI configured
  link_only                               = try(each.value.settings.link_only, false)
  
  # PKCE and authentication configuration via extra_config
  extra_config = merge(
    try(each.value.oidc.pkce_enabled, false) ? {
      "pkceEnabled" = "true"
      "pkceMethod"  = "S256"  # SHA-256 challenge method
    } : {},
    try(each.value.oidc.client_secret, null) == null ? {
      "clientAuthMethod" = "none"  # No client authentication for public PKCE clients
    } : {},
    try(each.value.oidc.backchannel_logout_url, null) != null ? {
      "backchannelLogoutUrl" = each.value.oidc.backchannel_logout_url
    } : {}
  )
}

# Create a flat map of all mappers for all providers
locals {
  # Create tuples of (provider_alias, mapper)
  mapper_tuples = flatten([
    for provider_key, provider in local.oidc_providers : [
      for mapper in provider.mappers : {
        key            = "${provider_key}-${mapper.name}"
        provider_alias = provider.alias
        mapper         = mapper
      }
    ]
  ])
  
  # Convert to map
  mappers = { for item in local.mapper_tuples : item.key => item }
}

# Configure attribute mappers for all identity providers
resource "keycloak_attribute_importer_identity_provider_mapper" "mappers" {
  for_each = local.mappers
  
  realm                   = local.config.realm
  identity_provider_alias = keycloak_oidc_identity_provider.providers[each.value.provider_alias].alias
  name                    = each.value.mapper.name
  
  claim_name              = each.value.mapper.claim_name
  user_attribute          = each.value.mapper.user_attribute
  
  extra_config = {
    syncMode = each.value.mapper.sync_mode
  }
}
