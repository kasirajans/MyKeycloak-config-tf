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

  registration_allowed     = var.registration_allowed
  reset_password_allowed   = var.reset_password_allowed
  remember_me              = var.remember_me
  verify_email             = var.verify_email
  login_with_email_allowed = var.login_with_email_allowed
  ssl_required             = var.ssl_required
  access_token_lifespan    = var.access_token_lifespan

  # Where this realm sends email from. Omitted when var.smtp_server is null.
  dynamic "smtp_server" {
    for_each = var.smtp_server != null ? [var.smtp_server] : []

    content {
      host              = smtp_server.value.host
      port              = tostring(smtp_server.value.port)
      from              = smtp_server.value.from
      from_display_name = smtp_server.value.from_display_name
      reply_to          = smtp_server.value.reply_to
      ssl               = smtp_server.value.ssl
      starttls          = smtp_server.value.starttls

      dynamic "auth" {
        for_each = smtp_server.value.username != null ? [1] : []

        content {
          username = smtp_server.value.username
          password = var.smtp_password
        }
      }
    }
  }
}
