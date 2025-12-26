# Custom Client Scopes Outputs

output "scopes" {
  description = "All custom client scopes configuration"
  value = {
    for key, scope in keycloak_openid_client_scope.scope : key => {
      id                     = scope.id
      name                   = scope.name
      description            = scope.description
      realm_id               = scope.realm_id
      include_in_token_scope = scope.include_in_token_scope
      consent_screen_text    = scope.consent_screen_text
      gui_order              = scope.gui_order
    }
  }
}

output "scope_ids" {
  description = "Map of scope names to their IDs"
  value = {
    for key, scope in keycloak_openid_client_scope.scope : key => scope.id
  }
}

output "scope_names" {
  description = "List of all custom scope names"
  value       = keys(keycloak_openid_client_scope.scope)
}

output "realm_name" {
  description = "Realm where scopes are created"
  value       = local.config.realm
}

# Mapper statistics
output "mapper_counts" {
  description = "Count of mappers by type"
  value = {
    user_property_mappers  = length(keycloak_openid_user_property_protocol_mapper.user_property)
    user_attribute_mappers = length(keycloak_openid_user_attribute_protocol_mapper.user_attribute)
    full_name_mappers      = length(keycloak_openid_full_name_protocol_mapper.full_name)
    hardcoded_mappers      = length(keycloak_openid_hardcoded_claim_protocol_mapper.hardcoded)
    realm_role_mappers     = length(keycloak_openid_user_realm_role_protocol_mapper.realm_roles)
    client_role_mappers    = length(keycloak_openid_user_client_role_protocol_mapper.client_roles)
    audience_mappers       = length(keycloak_openid_audience_protocol_mapper.audience)
    session_note_mappers   = length(keycloak_openid_user_session_note_protocol_mapper.session_note)
    total_mappers = (
      length(keycloak_openid_user_property_protocol_mapper.user_property) +
      length(keycloak_openid_user_attribute_protocol_mapper.user_attribute) +
      length(keycloak_openid_full_name_protocol_mapper.full_name) +
      length(keycloak_openid_hardcoded_claim_protocol_mapper.hardcoded) +
      length(keycloak_openid_user_realm_role_protocol_mapper.realm_roles) +
      length(keycloak_openid_user_client_role_protocol_mapper.client_roles) +
      length(keycloak_openid_audience_protocol_mapper.audience) +
      length(keycloak_openid_user_session_note_protocol_mapper.session_note)
    )
  }
}

# Detailed mapper information
output "mappers_by_scope" {
  description = "Mappers grouped by scope"
  value = {
    for scope_name in keys(local.scopes) : scope_name => [
      for mapper_key, mapper in local.mappers_map :
      mapper.mapper_name if mapper.scope_name == scope_name
    ]
  }
}
