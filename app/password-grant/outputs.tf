# Password Grant Clients Output
output "clients" {
  description = "All Password Grant (ROPC) clients configuration"
  value = {
    for key, client in keycloak_openid_client.password_grant : key => {
      client_id          = random_uuid.client[key].result
      client_name        = client.name
      client_type        = try(local.clients[key].access_type, "CONFIDENTIAL")
      flow_type          = "Resource Owner Password Credentials (ROPC)"
      internal_id        = client.id
      resource_uuid      = random_uuid.client[key].result
      scope_id           = keycloak_openid_client_scope.password_scope[key].id
      token_url          = "${var.keycloak_url}/realms/${local.config.realm}/protocol/openid-connect/token"
      grant_type         = "password"
      scopes             = ["openid", "profile", "email"]
      has_client_secret  = try(local.clients[key].access_type, "CONFIDENTIAL") == "CONFIDENTIAL"
    }
  }
  sensitive = true
}

# Password Grant Client Secrets - Only for CONFIDENTIAL clients
output "password_grant_client_secrets" {
  description = "Client secrets for CONFIDENTIAL Password Grant applications"
  value = {
    for key, _ in local.clients : key => (
      try(local.clients[key].access_type, "CONFIDENTIAL") == "CONFIDENTIAL" 
      ? random_password.client_secret[key].result 
      : "N/A - Public Client"
    )
  }
  sensitive = true
}

# Realm Information
output "realm_name" {
  description = "Realm where Password Grant clients are created"
  value       = local.config.realm
}
