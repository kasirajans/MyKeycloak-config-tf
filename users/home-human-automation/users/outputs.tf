output "user_ids" {
  description = "Map of \"<home>/<username>\" -> Keycloak user ID."
  value       = { for k, m in module.user : k => m.id }
}

output "group_ids" {
  description = "Map of home name -> Keycloak group ID."
  value       = { for name, m in module.home_group : name => m.id }
}

output "initial_passwords" {
  description = "Map of \"<home>/<username>\" -> the random starting password Terraform generated (users with random_password: true only). Read with: terraform output -json initial_passwords"
  value       = { for k, p in random_password.user : k => p.result }
  sensitive   = true
}
