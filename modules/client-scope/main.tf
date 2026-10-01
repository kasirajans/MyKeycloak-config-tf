terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.0"
    }
  }
}

resource "keycloak_openid_client_scope" "this" {
  realm_id                = var.realm_id
  name                     = var.name
  description              = var.description
  include_in_token_scope   = var.include_in_token_scope
}

resource "keycloak_openid_audience_protocol_mapper" "audience" {
  count = var.audience != null ? 1 : 0

  realm_id        = var.realm_id
  client_scope_id = keycloak_openid_client_scope.this.id
  name            = "${var.name}-audience"

  included_custom_audience = var.audience
}
