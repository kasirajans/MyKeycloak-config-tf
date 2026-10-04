locals {
  # All users in one file — users.yml — grouped under one key per home. Each home also
  # becomes a Keycloak group (below).
  users_data = fileexists("${path.module}/users.yml") ? yamldecode(file("${path.module}/users.yml")) : {}
  homes      = toset(keys(local.users_data))

  # Flatten every home's list into individual records, tagged with their home and with
  # roles resolved from account_type:
  #   - "owner"  -> also gets "home-admin" (this home's admin), on top of "resident" from
  #                 group membership.
  #   - "member" -> no automatic extra role beyond "resident".
  #   - "guest"  -> gets "guest", and is left out of the home group, so no "resident".
  # roles: on a user entry adds further grants on top of that (kc-admin:*, <client>:<role>).
  users = merge([
    for home, members in local.users_data : {
      for u in members :
      "${home}/${u.username}" => merge(u, {
        home = home
        resolved_roles = concat(
          u.account_type == "owner" ? ["home-admin"] : [],
          u.account_type == "guest" ? ["guest"] : [],
          try(u.roles, [])
        )
      })
    }
  ]...)

  # Owners and members per home (not guests), for each home's keycloak_group_memberships.
  member_keys_by_home = {
    for home in local.homes :
    home => [for k, u in local.users : k if u.home == home && u.account_type != "guest"]
  }

  # Combined lookup: realm roles by plain name and Keycloak admin roles as
  # "kc-admin:<name>" (both from ../roles), client roles as "<client_name>:<role>"
  # (from app/homeAutomation).
  role_ids = merge(
    data.terraform_remote_state.roles.outputs.role_ids,
    try(data.terraform_remote_state.home_automation_app[0].outputs.role_ids, {}),
  )
}

# Realm and Keycloak admin roles live in ../roles' own state — read-only here, this
# state never creates or modifies them. Apply ../roles first.
data "terraform_remote_state" "roles" {
  backend = "local"

  config = {
    path = "${path.module}/../roles/terraform.tfstate"
  }
}

# App-specific client roles live in app/homeAutomation/'s state (see that directory's
# README) — read-only here. Only read once that state exists; until then there are no
# client roles to grant, and referencing one from a user's roles: fails on the
# role_ids lookup below.
locals {
  home_automation_state = "${path.module}/../../../app/homeAutomation/terraform.tfstate"
}

data "terraform_remote_state" "home_automation_app" {
  count   = fileexists(local.home_automation_state) ? 1 : 0
  backend = "local"

  config = {
    path = local.home_automation_state
  }
}

# One Keycloak group per home. Every member auto-gets the "resident" role via
# keycloak_group_roles (inside modules/group). "home-admin" (account_type: owner) and any
# other roles: stay individual grants; scoping "admin of which home" is the combination
# of the home-admin role + this group membership, checked by the consuming app.
module "home_group" {
  source   = "../../../modules/group"
  for_each = local.homes

  realm_id = var.realm_id
  name     = each.value
  role_ids = [local.role_ids["resident"]]
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
  attributes = { site = each.value.home }

  # Only applied when the user is first created — Keycloak owns the password after that.
  set_initial_password = try(each.value.random_password, true)
  initial_password     = try(random_password.user[each.key].result, null)
  temporary_password   = try(each.value.temporary_password, true)

  role_ids = [for r in each.value.resolved_roles : local.role_ids[r]]
}
