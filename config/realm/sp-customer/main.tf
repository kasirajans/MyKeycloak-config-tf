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

# Create SP Customer Realm
resource "keycloak_realm" "sp_customer" {
  realm             = var.realm_name
  enabled           = true
  display_name      = var.realm_display_name
  display_name_html = var.realm_display_name_html

  # Login settings
  login_with_email_allowed  = var.login_with_email_allowed
  registration_allowed      = var.registration_allowed
  registration_email_as_username = var.registration_email_as_username
  reset_password_allowed    = var.reset_password_allowed
  remember_me               = var.remember_me
  verify_email              = var.verify_email
  edit_username_allowed     = var.edit_username_allowed
  duplicate_emails_allowed  = false

  # Session settings
  sso_session_idle_timeout     = "${var.sso_session_idle_timeout}s"
  sso_session_max_lifespan     = "${var.sso_session_max_lifespan}s"
  offline_session_idle_timeout = "${var.offline_session_idle_timeout}s"
  offline_session_max_lifespan = "${var.offline_session_max_lifespan}s"
  access_token_lifespan        = "${var.access_token_lifespan}s"

  # Security settings
  ssl_required                  = var.ssl_required
  password_policy               = var.password_policy
  revoke_refresh_token          = true
  refresh_token_max_reuse       = 0

  # Internationalization
  internationalization {
    supported_locales = var.supported_locales
    default_locale    = var.default_locale
  }

  # SMTP settings (optional)
  dynamic "smtp_server" {
    for_each = var.smtp_server_enabled ? [1] : []
    content {
      host = var.smtp_host
      port = var.smtp_port
      from = var.smtp_from
      from_display_name = var.smtp_from_display_name
      ssl  = var.smtp_ssl
      starttls = var.smtp_starttls
      auth {
        username = var.smtp_username
        password = var.smtp_password
      }
    }
  }

  # Security defenses
  security_defenses {
    headers {
      x_frame_options                     = "SAMEORIGIN"
      content_security_policy             = "frame-src 'self'; frame-ancestors 'self'; object-src 'none';"
      content_security_policy_report_only = ""
      x_content_type_options              = "nosniff"
      x_robots_tag                        = "none"
      x_xss_protection                    = "1; mode=block"
      strict_transport_security           = "max-age=31536000; includeSubDomains"
    }
    brute_force_detection {
      permanent_lockout                 = false
      max_login_failures                = 5
      wait_increment_seconds            = 60
      quick_login_check_milli_seconds   = 1000
      minimum_quick_login_wait_seconds  = 60
      max_failure_wait_seconds          = 900
      failure_reset_time_seconds        = 43200
    }
  }

  # Browser settings
  browser_flow    = "browser"
  registration_flow = "registration"
  direct_grant_flow = "direct grant"
  reset_credentials_flow = "reset credentials"
  client_authentication_flow = "clients"
}
