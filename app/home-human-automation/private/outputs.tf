output "client_ids" {
  description = "Map of client_id -> Keycloak internal ID for every private client in this state."
  value       = { for k, m in module.client : k => m.id }
}

output "client_secrets" {
  description = "Map of client_id -> generated client secret. Read with: terraform output -json client_secrets"
  value       = { for k, m in module.client : k => m.client_secret }
  sensitive   = true
}

output "service_account_user_ids" {
  description = "Map of client_id -> service-account user ID, for granting the client roles."
  value       = { for k, m in module.client : k => m.service_account_user_id }
}
