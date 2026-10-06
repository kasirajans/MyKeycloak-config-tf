terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.0"
    }
  }
}

resource "keycloak_user" "this" {
  realm_id   = var.realm_id
  username   = var.username
  enabled    = var.enabled
  email      = var.email
  first_name = var.first_name
  last_name  = var.last_name
  attributes = var.attributes

  dynamic "initial_password" {
    for_each = var.set_initial_password ? [1] : []

    content {
      value     = var.initial_password
      temporary = var.temporary_password
    }
  }

  lifecycle {
    # Keycloak owns required actions: a temporary password adds UPDATE_PASSWORD, and it's
    # cleared once the user sets a new one. Without this, every plan would remove it and
    # turn temporary passwords into permanent ones.
    ignore_changes = [required_actions]
  }
}

resource "keycloak_user_roles" "this" {
  count = length(var.role_ids) > 0 ? 1 : 0

  realm_id = var.realm_id
  user_id  = keycloak_user.this.id
  role_ids = var.role_ids
}
