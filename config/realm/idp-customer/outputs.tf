output "realm_id" {
  description = "The ID of the created realm"
  value       = keycloak_realm.idp_customer.id
}

output "realm_name" {
  description = "The name of the created realm"
  value       = keycloak_realm.idp_customer.realm
}

output "realm_display_name" {
  description = "The display name of the realm"
  value       = keycloak_realm.idp_customer.display_name
}

output "realm_enabled" {
  description = "Whether the realm is enabled"
  value       = keycloak_realm.idp_customer.enabled
}

output "login_settings" {
  description = "Login configuration settings"
  value = {
    login_with_email_allowed       = keycloak_realm.idp_customer.login_with_email_allowed
    registration_allowed           = keycloak_realm.idp_customer.registration_allowed
    registration_email_as_username = keycloak_realm.idp_customer.registration_email_as_username
    reset_password_allowed         = keycloak_realm.idp_customer.reset_password_allowed
    verify_email                   = keycloak_realm.idp_customer.verify_email
  }
}

output "session_settings" {
  description = "Session timeout settings"
  value = {
    sso_session_idle_timeout     = keycloak_realm.idp_customer.sso_session_idle_timeout
    sso_session_max_lifespan     = keycloak_realm.idp_customer.sso_session_max_lifespan
    offline_session_idle_timeout = keycloak_realm.idp_customer.offline_session_idle_timeout
    access_token_lifespan        = keycloak_realm.idp_customer.access_token_lifespan
  }
}

output "security_settings" {
  description = "Security configuration"
  value = {
    ssl_required     = keycloak_realm.idp_customer.ssl_required
    password_policy  = keycloak_realm.idp_customer.password_policy
  }
}

output "realm_endpoints" {
  description = "Important realm endpoints"
  value = {
    auth_url     = "${var.keycloak_url}/realms/${keycloak_realm.idp_customer.realm}/protocol/openid-connect/auth"
    token_url    = "${var.keycloak_url}/realms/${keycloak_realm.idp_customer.realm}/protocol/openid-connect/token"
    userinfo_url = "${var.keycloak_url}/realms/${keycloak_realm.idp_customer.realm}/protocol/openid-connect/userinfo"
    logout_url   = "${var.keycloak_url}/realms/${keycloak_realm.idp_customer.realm}/protocol/openid-connect/logout"
    issuer_url   = "${var.keycloak_url}/realms/${keycloak_realm.idp_customer.realm}"
  }
}
