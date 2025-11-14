# Outputs for all realms
output "realms" {
  description = "Map of all created realms with their details"
  value = {
    for realm_key, realm in keycloak_realm.realms : realm_key => {
      id           = realm.id
      name         = realm.realm
      display_name = realm.display_name
      enabled      = realm.enabled
    }
  }
}

# Individual realm outputs for convenience
output "idp_customer_realm" {
  description = "IDP Customer realm details"
  value = contains(keys(keycloak_realm.realms), "idp-customer") ? {
    id           = keycloak_realm.realms["idp-customer"].id
    name         = keycloak_realm.realms["idp-customer"].realm
    display_name = keycloak_realm.realms["idp-customer"].display_name
    enabled      = keycloak_realm.realms["idp-customer"].enabled
  } : null
}

output "sp_customer_realm" {
  description = "SP Customer realm details"
  value = contains(keys(keycloak_realm.realms), "sp-customer") ? {
    id           = keycloak_realm.realms["sp-customer"].id
    name         = keycloak_realm.realms["sp-customer"].realm
    display_name = keycloak_realm.realms["sp-customer"].display_name
    enabled      = keycloak_realm.realms["sp-customer"].enabled
  } : null
}

# Realm endpoints for all realms
output "realm_endpoints" {
  description = "OpenID Connect endpoints for all realms"
  value = {
    for realm_key, realm in keycloak_realm.realms : realm_key => {
      issuer                = "${var.keycloak_url}/realms/${realm.realm}"
      authorization         = "${var.keycloak_url}/realms/${realm.realm}/protocol/openid-connect/auth"
      token                 = "${var.keycloak_url}/realms/${realm.realm}/protocol/openid-connect/token"
      userinfo              = "${var.keycloak_url}/realms/${realm.realm}/protocol/openid-connect/userinfo"
      jwks                  = "${var.keycloak_url}/realms/${realm.realm}/protocol/openid-connect/certs"
      end_session           = "${var.keycloak_url}/realms/${realm.realm}/protocol/openid-connect/logout"
      introspection         = "${var.keycloak_url}/realms/${realm.realm}/protocol/openid-connect/token/introspect"
      revocation            = "${var.keycloak_url}/realms/${realm.realm}/protocol/openid-connect/revoke"
      device_authorization  = "${var.keycloak_url}/realms/${realm.realm}/protocol/openid-connect/auth/device"
    }
  }
}

# Login settings for all realms
output "login_settings" {
  description = "Login configuration settings for all realms"
  value = {
    for realm_key, realm in keycloak_realm.realms : realm_key => {
      login_with_email_allowed       = realm.login_with_email_allowed
      registration_allowed           = realm.registration_allowed
      registration_email_as_username = realm.registration_email_as_username
      reset_password_allowed         = realm.reset_password_allowed
      verify_email                   = realm.verify_email
    }
  }
}

# Session settings for all realms
output "session_settings" {
  description = "Session timeout settings for all realms"
  value = {
    for realm_key, realm in keycloak_realm.realms : realm_key => {
      sso_session_idle_timeout     = realm.sso_session_idle_timeout
      sso_session_max_lifespan     = realm.sso_session_max_lifespan
      offline_session_idle_timeout = realm.offline_session_idle_timeout
      access_token_lifespan        = realm.access_token_lifespan
    }
  }
}

# Security settings for all realms
output "security_settings" {
  description = "Security configuration for all realms"
  value = {
    for realm_key, realm in keycloak_realm.realms : realm_key => {
      ssl_required    = realm.ssl_required
      password_policy = realm.password_policy
    }
  }
}
