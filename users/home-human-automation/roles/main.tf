locals {
  # All roles in one file — roles.yml — grouped under one key per role type:
  #   - realm:    global (realm) roles, created here since they're a realm-wide
  #               identity concern, not tied to any one app.
  #   - kc-admin: Keycloak's own built-in admin roles (what a user can do in
  #               Keycloak/the IAM system itself), looked up, never created.
  roles_data       = fileexists("${path.module}/roles.yml") ? yamldecode(file("${path.module}/roles.yml")) : {}
  realm_roles      = { for r in try(local.roles_data.realm, []) : r.name => r }
  admin_role_names = toset([for r in try(local.roles_data["kc-admin"], []) : r.name])
}

# Keycloak's own built-in realm-management client, present automatically on every realm.
data "keycloak_openid_client" "realm_management" {
  realm_id  = var.realm_id
  client_id = "realm-management"
}

data "keycloak_role" "admin" {
  for_each = local.admin_role_names

  realm_id  = var.realm_id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = each.key
}

module "realm_role" {
  source   = "../../../modules/role"
  for_each = local.realm_roles

  realm_id    = var.realm_id
  name        = each.value.name
  description = try(each.value.description, null)
}
