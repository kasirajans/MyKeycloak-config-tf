# AIAgent Clients Output
output "aiagent_clients" {
  description = "All AIAgent (Client Credentials) clients configuration"
  value = {
    for key, client in keycloak_openid_client.aiagent : key => {
      app_name                = local.clients[key].app_name
      client_id               = random_uuid.client[key].result
      client_name             = client.name
      description             = client.description  # Format: owner;team;email
      client_type             = "CONFIDENTIAL"
      flow_type               = "Client Credentials"
      internal_id             = client.id
      resource_uuid           = random_uuid.client[key].result
      scope_id                = keycloak_openid_client_scope.aiagent_scope[key].id
      scope_name              = local.clients[key].scope
      service_account_user_id = client.service_account_user_id
      token_url               = "${var.keycloak_url}/realms/${local.config.realm}/protocol/openid-connect/token"
      grant_type              = "client_credentials"
      access_token_lifespan   = "1800"  # 30 minutes (hardcoded)

      # Parse description for easy access
      owner = split(";", client.description)[0]
      team  = split(";", client.description)[1]
      email = split(";", client.description)[2]
    }
  }
  sensitive = true
}

# AIAgent Client Secrets - Separate sensitive output
output "aiagent_client_secrets" {
  description = "Client secrets for AIAgent applications (48-character random secrets)"
  value = {
    for key, _ in local.clients : key => random_password.client_secret[key].result
  }
  sensitive = true
}

# Realm Information
output "realm_name" {
  description = "Realm where AIAgent clients are created"
  value       = local.config.realm
}

# Human-friendly summary
output "aiagent_summary" {
  description = "Human-friendly summary of AIAgent clients"
  value = {
    for key, client in keycloak_openid_client.aiagent : key => {
      app_name       = local.clients[key].app_name
      owner          = split(";", client.description)[0]
      team           = split(";", client.description)[1]
      email          = split(";", client.description)[2]
      scope          = local.clients[key].scope
      token_lifetime = "30 minutes"
    }
  }
}
