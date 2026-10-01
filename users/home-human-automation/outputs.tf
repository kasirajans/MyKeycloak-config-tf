output "user_ids" {
  description = "Map of \"<home>/<file>.yaml\" -> Keycloak user ID."
  value       = { for k, m in module.user : k => m.id }
}

output "group_ids" {
  description = "Map of home name -> Keycloak group ID."
  value       = { for name, m in module.home_group : name => m.id }
}
