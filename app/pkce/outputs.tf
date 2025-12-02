# PKCE Clients Output
output "clients" {
  description = "All PKCE (Authorization Code + PKCE) clients configuration"
  value = {
    for key, client in keycloak_openid_client.pkce : key => {
      client_id          = random_uuid.client[key].result
      client_name        = client.name
      client_type        = "PUBLIC"
      flow_type          = "Authorization Code + PKCE"
      internal_id        = client.id
      resource_uuid      = random_uuid.client[key].result
      scope_id           = keycloak_openid_client_scope.pkce_scope[key].id
      redirect_uris      = client.valid_redirect_uris
      web_origins        = client.web_origins
      authorization_url  = "${var.keycloak_url}/realms/${local.config.realm}/protocol/openid-connect/auth"
      token_url          = "${var.keycloak_url}/realms/${local.config.realm}/protocol/openid-connect/token"
      userinfo_url       = "${var.keycloak_url}/realms/${local.config.realm}/protocol/openid-connect/userinfo"
      logout_url         = "${var.keycloak_url}/realms/${local.config.realm}/protocol/openid-connect/logout"
      pkce_method        = "S256"
      scopes             = ["openid", "profile", "email"]
    }
  }
}

# Realm Information
output "realm_name" {
  description = "Realm where PKCE clients are created"
  value       = local.config.realm
}
