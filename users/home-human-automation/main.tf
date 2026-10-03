locals {
  # Global (realm) roles — roles/realm/roles.yml. Created here, since these are a
  # realm-wide identity concern, not tied to any one app.
  realm_roles_data = fileexists("${path.module}/roles/realm/roles.yml") ? yamldecode(file("${path.module}/roles/realm/roles.yml")) : { roles = [] }
  realm_roles      = { for r in local.realm_roles_data.roles : r.name => r }

  # References to Keycloak's own built-in admin roles — roles/admin/roles.yml. What a
  # user can do in Keycloak/the IAM system itself, looked up here for the same reason.
  admin_roles_data = fileexists("${path.module}/roles/admin/roles.yml") ? yamldecode(file("${path.module}/roles/admin/roles.yml")) : { admin_roles = [] }
  admin_role_names = toset(try(local.admin_roles_data.admin_roles, []))

  # One user.yml per home (home1/user.yml today), not one file per person — each lists
  # that home's members under "users:". The glob only matches files literally named
  # "user.yml", so a home's _example-user.yml (documentation) is naturally excluded.
  # The home is inferred from the folder name, same convention as team-from-folder for
  # app/aiAgent/clients/<team>/. Each home also becomes a Keycloak group (below).
  home_files = fileset(path.module, "*/user.yml")
  homes      = toset([for f in local.home_files : split("/", f)[0]])

  # Flatten every home's users: list into individual records, tagged with their home
  # and with roles resolved from account_type:
  #   - "owner"  -> also gets "home-admin" (this home's admin), on top of "resident" from
  #                 group membership.
  #   - "member" -> no automatic extra role beyond "resident".
  # roles: on a user entry adds further grants on top of that (kc-admin:*, <client>:<role>).
  users = merge([
    for f in local.home_files : {
      for u in yamldecode(file("${path.module}/${f}")).users :
      "${split("/", f)[0]}/${u.username}" => merge(u, {
        home = split("/", f)[0]
        resolved_roles = concat(
          u.account_type == "owner" ? ["home-admin"] : [],
          try(u.roles, [])
        )
      })
    }
  ]...)

  # Usernames per home, for each home's keycloak_group_memberships.
  usernames_by_home = {
    for home in local.homes :
    home => [for k, u in local.users : u.username if u.home == home]
  }

  # App-specific (client) roles are NOT owned here — they stay in app/homeAutomation/
  # (app-level, tied to that app's own clients) and are read via remote state.
  client_role_ids = try(data.terraform_remote_state.home_automation_app[0].outputs.role_ids, {})

  # Combined lookup: realm roles by plain name, Keycloak admin roles as "kc-admin:<name>",
  # client roles as "<client_name>:<role>" (already that shape in the remote output).
  # Note "home-admin" (realm role) and "kc-admin:<name>" are different keys.
  role_ids = merge(
    { for name, m in module.realm_role : name => m.id },
    { for name, d in data.keycloak_role.admin : "kc-admin:${name}" => d.id },
    local.client_role_ids,
  )
}

# App-specific client roles live in app/homeAutomation/'s state (see that directory's
# README) — read-only here, this state never creates or modifies them. Only read once
# that state exists; until then there are no client roles to grant, and referencing
# one from a user's roles: fails on the role_ids lookup below.
locals {
  home_automation_state = "${path.module}/../../app/homeAutomation/terraform.tfstate"
}

data "terraform_remote_state" "home_automation_app" {
  count   = fileexists(local.home_automation_state) ? 1 : 0
  backend = "local"

  config = {
    path = local.home_automation_state
  }
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
  source   = "../../modules/role"
  for_each = local.realm_roles

  realm_id    = var.realm_id
  name        = each.value.name
  description = try(each.value.description, null)
}

# One Keycloak group per home. Every member auto-gets the "resident" role via
# keycloak_group_roles (inside modules/group). "home-admin" (account_type: owner) and any
# other roles: stay individual grants; scoping "admin of which home" is the combination
# of the home-admin role + this group membership, checked by the consuming app.
module "home_group" {
  source   = "../../modules/group"
  for_each = local.homes

  realm_id = var.realm_id
  name     = each.value
  role_ids = [local.role_ids["resident"]]
}

resource "keycloak_group_memberships" "home" {
  for_each = local.homes

  realm_id = var.realm_id
  group_id = module.home_group[each.value].id
  members  = local.usernames_by_home[each.value]
}

module "user" {
  source   = "../../modules/user"
  for_each = local.users

  realm_id   = var.realm_id
  username   = each.value.username
  email      = try(each.value.email, null)
  enabled    = try(each.value.enabled, true)
  attributes = { site = each.value.home }

  role_ids = [for r in each.value.resolved_roles : local.role_ids[r]]
}
