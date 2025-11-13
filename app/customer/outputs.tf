# PKCE Clients - All PKCE type clients grouped together
output "pkce_clients" {
  description = "All PKCE (Authorization Code + PKCE) clients configuration"
  value = {
    webapp = {
      client_id          = random_uuid.pkce_client.result
      client_name        = keycloak_openid_client.pkce_client.name
      client_type        = "PUBLIC"
      flow_type          = "Authorization Code + PKCE"
      internal_id        = keycloak_openid_client.pkce_client.id
      resource_uuid      = random_uuid.pkce_client.result
      scope_id           = keycloak_openid_client_scope.pkce_custom_scope.id
      redirect_uris      = keycloak_openid_client.pkce_client.valid_redirect_uris
      web_origins        = keycloak_openid_client.pkce_client.web_origins
      authorization_url  = "${var.keycloak_url}/realms/${local.app_config.realm}/protocol/openid-connect/auth"
      token_url          = "${var.keycloak_url}/realms/${local.app_config.realm}/protocol/openid-connect/token"
      userinfo_url       = "${var.keycloak_url}/realms/${local.app_config.realm}/protocol/openid-connect/userinfo"
      logout_url         = "${var.keycloak_url}/realms/${local.app_config.realm}/protocol/openid-connect/logout"
      pkce_method        = "S256"
      scopes             = ["openid", "profile", "email"]
    }
  }
}

# M2M Clients - All M2M (Client Credentials) clients grouped together
output "m2m_clients" {
  description = "All M2M (Client Credentials) clients configuration"
  value = {
    backend_service = {
      client_id               = random_uuid.m2m_client.result
      client_name             = keycloak_openid_client.m2m_client.name
      client_type             = "CONFIDENTIAL"
      flow_type               = "Client Credentials"
      internal_id             = keycloak_openid_client.m2m_client.id
      resource_uuid           = random_uuid.m2m_client.result
      scope_id                = keycloak_openid_client_scope.m2m_custom_scope.id
      service_account_user_id = keycloak_openid_client.m2m_client.service_account_user_id
      token_url               = "${var.keycloak_url}/realms/${local.app_config.realm}/protocol/openid-connect/token"
      grant_type              = "client_credentials"
      scopes                  = ["openid"]
    }
  }
  sensitive = true
}

# M2M Client Secrets - Separate sensitive output
output "m2m_client_secrets" {
  description = "Client secrets for M2M applications"
  value = {
    backend_service = random_password.m2m_client_secret.result
  }
  sensitive = true
}

# Realm Information
output "realm_name" {
  description = "Realm where clients are created"
  value       = local.app_config.realm
}
