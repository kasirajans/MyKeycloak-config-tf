output "id" {
  description = "Keycloak's internal ID of the client (what other resources reference as client_id)."
  value       = keycloak_openid_client.this.id
}

output "client_id" {
  description = "The client_id string apps use to identify themselves."
  value       = keycloak_openid_client.this.client_id
}

output "client_secret" {
  description = "The generated client secret (CONFIDENTIAL clients only; null for PUBLIC)."
  value       = var.access_type == "CONFIDENTIAL" ? keycloak_openid_client.this.client_secret : null
  sensitive   = true
}

output "service_account_user_id" {
  description = "ID of the client's service-account user, for granting it roles (null when service accounts are off)."
  value       = try(keycloak_openid_client.this.service_account_user_id, null)
}
