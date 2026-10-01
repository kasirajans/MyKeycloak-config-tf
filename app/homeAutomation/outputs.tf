output "role_ids" {
  description = "Map of \"<client_name>:<role_name>\" -> Keycloak role ID, for the app-specific client roles owned here. Read by users/home-human-automation/ via terraform_remote_state to resolve residents' client-role references."
  value       = { for name, m in module.client_role : name => m.id }
}
