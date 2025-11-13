output "configured_providers" {
  description = "List of all configured identity providers"
  value = {
    for alias, provider in keycloak_oidc_identity_provider.providers : alias => {
      alias         = provider.alias
      display_name  = provider.display_name
      enabled       = provider.enabled
      internal_id   = provider.internal_id
      trust_email   = provider.trust_email
      store_tokens  = provider.store_token
      sync_mode     = provider.sync_mode
    }
  }
}

output "provider_details" {
  description = "Detailed information about each provider"
  value = {
    for alias, provider in local.oidc_providers : alias => {
      display_name      = provider.display_name
      enabled           = provider.enabled
      authorization_url = provider.oidc.authorization_url
      token_url         = provider.oidc.token_url
      mappers_count     = length(provider.mappers)
      gui_order         = try(provider.settings.gui_order, null)
    }
  }
}

output "attribute_mappers" {
  description = "Summary of configured attribute mappers by provider"
  value = {
    for alias, provider in local.oidc_providers : alias => [
      for mapper in provider.mappers : {
        name           = mapper.name
        claim_name     = mapper.claim_name
        user_attribute = mapper.user_attribute
        sync_mode      = mapper.sync_mode
      }
    ]
  }
}

output "login_url" {
  description = "URL to test the broker login"
  value       = "http://localhost:8080/realms/${local.config.realm}/account"
}
