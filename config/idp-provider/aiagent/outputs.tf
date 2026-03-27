output "okta_idp_alias" {
  value       = { for k, v in keycloak_oidc_identity_provider.providers : k => v.alias }
  description = "Okta Identity Provider alias(es) in AIAgent realm"
}

output "okta_idp_details" {
  value = {
    for k, v in keycloak_oidc_identity_provider.providers : k => {
      alias       = v.alias
      realm       = v.realm
      enabled     = v.enabled
      client_id   = v.client_id
      jwks_url    = v.jwks_url
      token_url   = v.token_url
      config_url  = "${v.token_url}/config"  # Discovery endpoint
    }
  }
  description = "Okta OIDC Identity Provider configuration details"
}

output "mapper_reference" {
  value = {
    description = "Attribute mappers must be configured manually or via REST API"
    mappers = {
      sub              = { claim_name = "sub", user_attribute = "sub" }
      email            = { claim_name = "email", user_attribute = "email" }
      firstName        = { claim_name = "given_name", user_attribute = "firstName" }
      lastName         = { claim_name = "family_name", user_attribute = "lastName" }
      username         = { claim_name = "preferred_username", user_attribute = "username" }
      appRoles         = { claim_name = "appRoles", user_attribute = "appRoles" }
      groups           = { claim_name = "groups", user_attribute = "groups" }
      okta_domain      = { claim_name = "iss", user_attribute = "okta_domain" }
    }
    instructions = "Add these mappers in Keycloak Admin Console: Identity Providers → okta-oidc → Mappers tab"
  }
  description = "Reference for OIDC attribute mappers to configure in Keycloak"
}
