output "pkce_client_id" {
  description = "Client ID for PKCE application"
  value       = keycloak_openid_client.pkce_client.client_id
}

output "pkce_client_internal_id" {
  description = "Internal Keycloak ID for PKCE client"
  value       = keycloak_openid_client.pkce_client.id
}

output "pkce_authorization_url" {
  description = "Authorization URL for PKCE flow"
  value       = "${var.keycloak_url}/realms/${var.keycloak_realm}/protocol/openid-connect/auth"
}

output "pkce_token_url" {
  description = "Token URL for PKCE flow"
  value       = "${var.keycloak_url}/realms/${var.keycloak_realm}/protocol/openid-connect/token"
}

output "pkce_redirect_uris" {
  description = "Configured redirect URIs for PKCE client"
  value       = keycloak_openid_client.pkce_client.valid_redirect_uris
}

output "m2m_client_id" {
  description = "Client ID for M2M application"
  value       = keycloak_openid_client.m2m_client.client_id
}

output "m2m_client_internal_id" {
  description = "Internal Keycloak ID for M2M client"
  value       = keycloak_openid_client.m2m_client.id
}

output "m2m_client_secret" {
  description = "Client secret for M2M application"
  value       = keycloak_openid_client.m2m_client.client_secret
  sensitive   = true
}

output "m2m_token_url" {
  description = "Token URL for M2M client credentials flow"
  value       = "${var.keycloak_url}/realms/${var.keycloak_realm}/protocol/openid-connect/token"
}

output "m2m_service_account_user_id" {
  description = "Service account user ID for M2M client"
  value       = keycloak_openid_client.m2m_client.service_account_user_id
}

output "realm_name" {
  description = "Realm where clients are created"
  value       = var.keycloak_realm
}

output "pkce_client_scope_id" {
  description = "Custom client scope ID for PKCE client"
  value       = keycloak_openid_client_scope.pkce_custom_scope.id
}

output "m2m_client_scope_id" {
  description = "Custom client scope ID for M2M client"
  value       = keycloak_openid_client_scope.m2m_custom_scope.id
}
