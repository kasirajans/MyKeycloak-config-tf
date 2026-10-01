terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.0"
    }
  }
}

resource "keycloak_role" "this" {
  realm_id        = var.realm_id
  name            = var.name
  description     = var.description
  client_id       = var.client_id
  composite_roles = var.composite_roles
}
