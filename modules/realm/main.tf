terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.0"
    }
  }
}

resource "keycloak_realm" "this" {
  realm        = var.realm
  enabled      = var.enabled
  display_name = var.display_name

  registration_allowed      = var.registration_allowed
  reset_password_allowed    = var.reset_password_allowed
  remember_me               = var.remember_me
  verify_email              = var.verify_email
  login_with_email_allowed  = var.login_with_email_allowed
  ssl_required              = var.ssl_required
  access_token_lifespan     = var.access_token_lifespan
}
