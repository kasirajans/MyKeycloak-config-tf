# M2M Clients Output
output "clients" {
  description = "All M2M (Client Credentials) clients configuration"
  value = {
    for key, client in keycloak_openid_client.m2m : key => {
      client_id               = random_uuid.client[key].result
      client_name             = client.name
      client_type             = "CONFIDENTIAL"
      flow_type               = "Client Credentials"
      internal_id             = client.id
      resource_uuid           = random_uuid.client[key].result
      scope_id                = keycloak_openid_client_scope.m2m_scope[key].id
      service_account_user_id = client.service_account_user_id
      token_url               = "${var.keycloak_url}/realms/${local.config.realm}/protocol/openid-connect/token"
      grant_type              = "client_credentials"
      scopes                  = ["openid"]
    }
  }
  sensitive = true
}

# M2M Client Secrets - Separate sensitive output
output "m2m_client_secrets" {
  description = "Client secrets for M2M applications (48-character random secrets)"
  value = {
    for key, _ in local.clients : key => random_password.client_secret[key].result
  }
  sensitive = true
}

# Realm Information
output "realm_name" {
  description = "Realm where M2M clients are created"
  value       = local.config.realm
}
