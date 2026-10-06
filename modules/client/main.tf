terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.0"
    }
  }
}

# One OpenID client, either:
#   - PUBLIC:       a browser/mobile app that can't keep a secret. Authorization code
#                   flow + PKCE (S256), no client secret, no service account.
#   - CONFIDENTIAL: a backend that can keep a secret. Keycloak generates the secret;
#                   optionally a service account for client-credentials.
#
# Not implemented yet (needed by app/aiAgent/): token-exchange audience wiring and the
# CIBA grant. Add them here as extra inputs rather than a separate module.
locals {
  is_public = var.access_type == "PUBLIC"

  # Ownership tracking: stored as custom client attributes so it's visible on the
  # client in Keycloak, not just inferable from this repo's folder layout.
  ownership_attributes = merge(
    var.owner_team != null ? { owner_team = var.owner_team } : {},
    var.project != null ? { project = var.project } : {},
  )
}

resource "keycloak_openid_client" "this" {
  realm_id    = var.realm_id
  client_id   = var.client_id
  name        = var.name
  description = var.description
  enabled     = var.enabled

  access_type = var.access_type

  standard_flow_enabled        = var.standard_flow_enabled
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
  service_accounts_enabled     = local.is_public ? false : var.service_accounts_enabled

  # PKCE is always on for public clients; optional for confidential ones.
  pkce_code_challenge_method = local.is_public ? "S256" : var.pkce_code_challenge_method

  root_url                        = var.root_url
  valid_redirect_uris             = var.valid_redirect_uris
  valid_post_logout_redirect_uris = var.valid_post_logout_redirect_uris
  web_origins                     = var.web_origins

  extra_config = merge(local.ownership_attributes, var.extra_config)
}
