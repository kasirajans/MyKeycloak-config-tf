terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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

# Read consumer users from CSV file
locals {
  users_csv_raw = csvdecode(file("${path.module}/user.csv"))
  
  # Generate email addresses based on realm name: firstname.lastname@realm.com
  users_csv = [
    for user in local.users_csv_raw : merge(user, {
      email = lower("${lookup(user, "first_name", "")}${lookup(user, "last_name", "") != "" ? ".${lookup(user, "last_name", "")}" : ""}@${var.keycloak_realm}.com")
    })
  ]
  
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

# Use existing realm (passed via variable)
data "keycloak_realm" "realm" {
  realm = var.keycloak_realm
}

# Create Keycloak groups in realm
resource "keycloak_group" "groups" {
  for_each = local.groups_to_create
  
  realm_id = data.keycloak_realm.realm.id
  name     = each.key
}

# Generate random passwords for each user
# Password will meet policy: upperCase(1) and length(8) and digits(1)
resource "random_password" "user_passwords" {
  for_each = { for user in local.users_csv : user.email => user }
  
  length           = 16
  special          = true
  upper            = true
  lower            = true
  numeric          = true
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!@#$%^&*"
  
  keepers = {
    email = each.value.email
  }
}

# Create Keycloak users in realm
resource "keycloak_user" "users" {
  for_each = { for user in local.users_csv : user.email => user }

  realm_id = data.keycloak_realm.realm.id
  username = each.value.email  # Use email as username
  enabled  = tobool(lookup(each.value, "enabled", "true"))

  email          = each.value.email
  email_verified = tobool(lookup(each.value, "email_verified", "false"))
  first_name     = lookup(each.value, "first_name", "")
  last_name      = lookup(each.value, "last_name", "")

  initial_password {
    value     = random_password.user_passwords[each.key].result
    temporary = tobool(lookup(each.value, "temporary_password", "true"))
  }
}

# Assign users to groups
resource "keycloak_user_groups" "user_groups" {
  for_each = { 
    for user in local.users_csv : user.email => user 
    if lookup(user, "groups", "") != ""
  }

  realm_id = data.keycloak_realm.realm.id
  user_id  = keycloak_user.users[each.key].id
  group_ids = [
    for group_name in split(",", each.value.groups) : 
    keycloak_group.groups[trimspace(group_name)].id
  ]
}
