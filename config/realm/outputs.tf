output "realm_ids" {
  value       = { for name, m in module.realm : name => m.id }
  description = "Map of realm name -> internal Keycloak realm ID, e.g. realm_ids[\"customer\"]."
}

output "realms" {
  value       = { for name, m in module.realm : name => m.realm }
  description = "Map of realm name -> realm name (identity map; useful for terraform_remote_state consumers)."
}
