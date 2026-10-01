locals {
  # clients/<client_name>.yaml holds both that client's own config (appconfig:, once
  # client creation is built) and its app-specific roles (roles:) together — one file
  # per client, rather than a separate roles/client/<name>/ tree, since a client's roles
  # are always 1:1 with that client. Global/IAM roles and users live in
  # users/home-human-automation/ instead (a realm-wide identity concern).
  client_files = [for f in fileset("${path.module}/clients", "*.yaml") : f if !startswith(f, "_example")]
  client_names = toset([for f in local.client_files : trimsuffix(f, ".yaml")])

  client_roles = merge([
    for f in local.client_files : {
      for r in try(yamldecode(file("${path.module}/clients/${f}")).roles, []) :
      "${trimsuffix(f, ".yaml")}:${r.name}" => merge(r, { client_name = trimsuffix(f, ".yaml") })
    }
  ]...)
}

# The app clients that own the roles above. Looked up, not created here — actual client
# creation isn't implemented yet; each clients/<name>.yaml's client_name must already
# exist in Keycloak.
data "keycloak_openid_client" "app_client" {
  for_each = local.client_names

  realm_id  = var.realm_id
  client_id = each.key
}

module "client_role" {
  source   = "../../modules/role"
  for_each = local.client_roles

  realm_id    = var.realm_id
  name        = each.value.name
  description = try(each.value.description, null)
  client_id   = data.keycloak_openid_client.app_client[each.value.client_name].id
}
