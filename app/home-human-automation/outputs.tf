output "role_ids" {
  description = "Map of \"<client_name>:<role_name>\" -> Keycloak role ID, for the app-specific client roles owned here. For reference; users/home-human-automation/ looks roles up by name instead."
  value       = { for name, m in module.client_role : name => m.id }
}
