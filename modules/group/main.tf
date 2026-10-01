terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.0"
    }
  }
}

resource "keycloak_group" "this" {
  realm_id   = var.realm_id
  name       = var.name
  parent_id  = var.parent_id
  attributes = var.attributes
}

resource "keycloak_group_roles" "this" {
  count = length(var.role_ids) > 0 ? 1 : 0

  realm_id = var.realm_id
  group_id = keycloak_group.this.id
  role_ids = var.role_ids
}
