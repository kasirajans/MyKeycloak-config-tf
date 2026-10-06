output "client_ids" {
  description = "Map of client_id -> Keycloak internal ID for every public client in this state."
  value       = { for k, m in module.client : k => m.id }
}

output "oidc_discovery_url" {
  description = "The realm's OIDC discovery document. Most OIDC libraries only need this (or the issuer) plus the client_id."
  value       = data.http.oidc_discovery.url
}

output "client_configs" {
  description = "Map of client_id -> everything an app needs for the authorization code + PKCE flow. Read with: terraform output -json client_configs"
  value = {
    for k, m in module.client : k => {
      client_id             = m.client_id
      issuer                = local.oidc.issuer
      authorization_url     = local.oidc.authorization_endpoint
      token_url             = local.oidc.token_endpoint
      userinfo_url          = local.oidc.userinfo_endpoint
      end_session_url       = local.oidc.end_session_endpoint
      jwks_url              = local.oidc.jwks_uri
      grant_type            = "authorization_code"
      response_type         = "code"
      code_challenge_method = "S256"
      scope                 = "openid profile email"
      redirect_uris         = try(local.clients[k].redirect_uris, [])
    }
  }
}
