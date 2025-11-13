terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5"
    }
  }
}

provider "keycloak" {
  client_id = var.keycloak_client_id
  url       = var.keycloak_url
  username  = var.keycloak_username
  password  = var.keycloak_password
  realm     = var.keycloak_admin_realm
}

# Read admin users from CSV file
locals {
  users_csv = csvdecode(file("${path.module}/user.csv"))
  
  # Extract unique group names from CSV
  all_groups = distinct(flatten([
    for user in local.users_csv : 
    split(",", lookup(user, "groups", ""))
    if lookup(user, "groups", "") != ""
  ]))
  
  # Map group names to create
  groups_to_create = toset([
    for group in local.all_groups : trimspace(group)
    if trimspace(group) != ""
  ])
}

# Create Keycloak groups in master realm
resource "keycloak_group" "groups" {
  for_each = local.groups_to_create
  
  realm_id = var.keycloak_realm
  name     = each.key
}

# Create Keycloak admin users in master realm
resource "keycloak_user" "users" {
  for_each = { for user in local.users_csv : user.username => user }

  realm_id = var.keycloak_realm
  username = each.value.username
  enabled  = tobool(lookup(each.value, "enabled", "true"))

  email          = each.value.email
  email_verified = tobool(lookup(each.value, "email_verified", "false"))
  first_name     = lookup(each.value, "first_name", "")
  last_name      = lookup(each.value, "last_name", "")

  initial_password {
    value     = lookup(each.value, "password", "ChangeMe123!")
    temporary = tobool(lookup(each.value, "temporary_password", "true"))
  }
}

# Assign admin users to groups
resource "keycloak_user_groups" "user_groups" {
  for_each = { 
    for user in local.users_csv : user.username => user 
    if lookup(user, "groups", "") != ""
  }

  realm_id = var.keycloak_realm
  user_id  = keycloak_user.users[each.key].id
  group_ids = [
    for group_name in split(",", each.value.groups) : 
    keycloak_group.groups[trimspace(group_name)].id
  ]
}
