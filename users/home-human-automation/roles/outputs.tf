output "role_ids" {
  description = "Map of role name -> Keycloak role ID: realm roles by plain name (e.g. \"home-admin\"), Keycloak admin roles as \"kc-admin:<name>\". For reference; ../users looks roles up by name instead."
  value = merge(
    { for name, m in module.realm_role : name => m.id },
    { for name, d in data.keycloak_role.admin : "kc-admin:${name}" => d.id },
  )
}
