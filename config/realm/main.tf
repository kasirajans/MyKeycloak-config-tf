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

# Load realms configuration from YAML file
locals {
  realms_config = yamldecode(file("${path.module}/realms.yml"))
  realms        = { for realm in local.realms_config.realms : realm.name => realm }
}

# Create all realms defined in realms.yml
resource "keycloak_realm" "realms" {
  for_each = local.realms

  realm             = each.value.name
  enabled           = each.value.enabled
  display_name      = each.value.display_name
  display_name_html = each.value.display_name_html

  # Login settings
  login_with_email_allowed       = each.value.login_with_email_allowed
  registration_allowed           = each.value.registration_allowed
  registration_email_as_username = each.value.registration_email_as_username
  reset_password_allowed         = each.value.reset_password_allowed
  remember_me                    = each.value.remember_me
  verify_email                   = each.value.verify_email
  edit_username_allowed          = each.value.edit_username_allowed
  duplicate_emails_allowed       = each.value.duplicate_emails_allowed

  # Session settings
  sso_session_idle_timeout     = "${each.value.sso_session_idle_timeout}s"
  sso_session_max_lifespan     = "${each.value.sso_session_max_lifespan}s"
  offline_session_idle_timeout = "${each.value.offline_session_idle_timeout}s"
  offline_session_max_lifespan = "${each.value.offline_session_max_lifespan}s"
  access_token_lifespan        = "${each.value.access_token_lifespan}s"

  # Security settings
  ssl_required            = each.value.ssl_required
  password_policy         = each.value.password_policy
  revoke_refresh_token    = each.value.revoke_refresh_token
  refresh_token_max_reuse = each.value.refresh_token_max_reuse

  # Internationalization
  internationalization {
    supported_locales = each.value.supported_locales
    default_locale    = each.value.default_locale
  }

  # SMTP settings (optional)
  dynamic "smtp_server" {
    for_each = lookup(local.realms_config, "smtp_server", null) != null && lookup(local.realms_config.smtp_server, "enabled", false) ? [1] : []
    content {
      host              = local.realms_config.smtp_server.host
      port              = local.realms_config.smtp_server.port
      from              = local.realms_config.smtp_server.from
      from_display_name = local.realms_config.smtp_server.from_display_name
      ssl               = local.realms_config.smtp_server.ssl
      starttls          = local.realms_config.smtp_server.starttls
      auth {
        username = local.realms_config.smtp_server.username
        password = local.realms_config.smtp_server.password
      }
    }
  }

  # Security defenses
  security_defenses {
    headers {
      x_frame_options                     = each.value.security_defenses.headers.x_frame_options
      content_security_policy             = each.value.security_defenses.headers.content_security_policy
      content_security_policy_report_only = ""
      x_content_type_options              = each.value.security_defenses.headers.x_content_type_options
      x_robots_tag                        = each.value.security_defenses.headers.x_robots_tag
      x_xss_protection                    = each.value.security_defenses.headers.x_xss_protection
      strict_transport_security           = each.value.security_defenses.headers.strict_transport_security
    }
    brute_force_detection {
      permanent_lockout                = each.value.security_defenses.brute_force.permanent_lockout
      max_login_failures               = each.value.security_defenses.brute_force.max_login_failures
      wait_increment_seconds           = each.value.security_defenses.brute_force.wait_increment_seconds
      quick_login_check_milli_seconds  = each.value.security_defenses.brute_force.quick_login_check_milli_seconds
      minimum_quick_login_wait_seconds = each.value.security_defenses.brute_force.minimum_quick_login_wait_seconds
      max_failure_wait_seconds         = each.value.security_defenses.brute_force.max_failure_wait_seconds
      failure_reset_time_seconds       = each.value.security_defenses.brute_force.failure_reset_time_seconds
    }
  }

  # Browser settings
  browser_flow               = each.value.browser_flow
  registration_flow          = each.value.registration_flow
  direct_grant_flow          = each.value.direct_grant_flow
  reset_credentials_flow     = each.value.reset_credentials_flow
  client_authentication_flow = each.value.client_authentication_flow
}
