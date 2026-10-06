locals {
  # All users in one file — users.yml — grouped under one key per home. Each home also
  # becomes a Keycloak group (below).
  users_data = fileexists("${path.module}/users.yml") ? yamldecode(file("${path.module}/users.yml")) : {}
  homes      = toset(keys(local.users_data))

  # What each account_type means — which roles it gives and whether the user joins their
  # home's group — lives in account_types.yml, not here.
  account_types_data = yamldecode(file("${path.module}/account_types.yml"))
  account_types      = local.account_types_data.account_types
  home_group_roles   = try(local.account_types_data.home_group_roles, [])

  # Flatten every home's list into individual records, tagged with their home, whether
  # they join the home group, and their direct roles: the account type's roles plus the
  # user's own roles: (kc-admin:*, <client>:<role>, ...). An account_type missing from
  # account_types.yml fails here with "key not found".
  users = merge([
    for home, members in local.users_data : {
      for u in members :
      "${home}/${u.username}" => merge(u, {
        home           = home
        in_home_group  = merge({ home_group = false }, local.account_types[u.account_type]).home_group
        resolved_roles = concat(merge({ roles = [] }, local.account_types[u.account_type]).roles, try(u.roles, []))
      })
    }
  ]...)

  # Users per home who join its group (home_group: true), for keycloak_group_memberships.
  member_keys_by_home = {
    for home in local.homes :
    home => [for k, u in local.users : k if u.home == home && u.in_home_group]
  }

  # Every role referenced anywhere above (users' roles plus home_group_roles),
  # parsed into where it lives in Keycloak:
  #   "<name>"            a realm role (from ../roles)
  #   "kc-admin:<name>"   a Keycloak admin role on the built-in realm-management client
  #   "<client>:<name>"   an app role on that client (from app/home-human-automation)
  role_refs = toset(concat(local.home_group_roles, flatten([for u in local.users : u.resolved_roles])))

  roles = {
    for ref in local.role_refs : ref => {
      client = length(split(":", ref)) > 1 ? (split(":", ref)[0] == "kc-admin" ? "realm-management" : split(":", ref)[0]) : null
      name   = element(split(":", ref), length(split(":", ref)) - 1)
    }
  }
  role_clients = toset(compact([for r in local.roles : r.client]))

  role_ids = { for ref, d in data.keycloak_role.role : ref => d.id }
}

# Roles are looked up by name in Keycloak itself — no links to other folders' state
# files, so this folder works the same for any realm and survives folders moving. A role
# that doesn't exist yet fails the plan; create it first (../roles for realm roles,
# app/home-human-automation for app roles).
data "keycloak_openid_client" "role_client" {
  for_each = local.role_clients

  realm_id  = var.realm_id
  client_id = each.key
}

data "keycloak_role" "role" {
  for_each = local.roles

  realm_id  = var.realm_id
  client_id = each.value.client != null ? data.keycloak_openid_client.role_client[each.value.client].id : null
  name      = each.value.name
}

# One Keycloak group per home. Every member gets home_group_roles (account_types.yml)
# via keycloak_group_roles (inside modules/group). An account type's own roles (e.g.
# "home-admin" for owners) and any other roles: stay individual grants; scoping "admin of which home" is the combination
# of the home-admin role + this group membership, checked by the consuming app.
module "home_group" {
  source   = "../../../modules/group"
  for_each = local.homes

  realm_id = var.realm_id
  name     = each.value
  role_ids = [for r in local.home_group_roles : local.role_ids[r]]
}

resource "keycloak_group_memberships" "home" {
  for_each = local.homes

  realm_id = var.realm_id
  group_id = module.home_group[each.value].id
  # Read from module.user so Terraform creates the users before adding them to the group.
  members = [for k in local.member_keys_by_home[each.value] : module.user[k].username]
}

# A random starting password for every user with random_password: true (the default).
# Read them with: terraform output -json initial_passwords
resource "random_password" "user" {
  for_each = { for k, u in local.users : k => u if try(u.random_password, true) }

  length           = 16
  special          = true
  override_special = "!@#%*-_+"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

module "user" {
  source   = "../../../modules/user"
  for_each = local.users

  realm_id   = var.realm_id
  username   = each.value.username
  email      = try(each.value.email, null)
  first_name = try(each.value.first_name, null)
  last_name  = try(each.value.last_name, null)
  enabled    = try(each.value.enabled, true)
  # No custom attributes: the realm's user profile doesn't declare any, so Keycloak would
  # silently drop them (and plan would show a change every run). A user's home is their
  # home-group membership.

  # Only applied when the user is first created — Keycloak owns the password after that.
  set_initial_password = try(each.value.random_password, true)
  initial_password     = try(random_password.user[each.key].result, null)
  temporary_password   = try(each.value.temporary_password, true)

  role_ids = [for r in each.value.resolved_roles : local.role_ids[r]]
}
