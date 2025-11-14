output "realm_id" {
  description = "ID of the realm"
  value       = data.keycloak_realm.realm.id
}

output "realm_name" {
  description = "Name of the realm"
  value       = data.keycloak_realm.realm.realm
}

output "created_users" {
  description = "Map of created usernames to their Keycloak user IDs"
  value = {
    for username, user in keycloak_user.users : username => user.id
  }
}

output "created_groups" {
  description = "Map of created group names to their Keycloak group IDs"
  value = {
    for name, group in keycloak_group.groups : name => group.id
  }
}

output "user_count" {
  description = "Total number of consumer users created"
  value       = length(keycloak_user.users)
}

output "users_with_groups" {
  description = "List of users assigned to groups"
  value       = keys(keycloak_user_groups.user_groups)
}

output "user_passwords" {
  description = "Generated passwords for users (SENSITIVE - store securely!)"
  value = {
    for email, password in random_password.user_passwords : email => password.result
  }
  sensitive = true
}

output "user_credentials_summary" {
  description = "User login credentials summary"
  value = {
    for email, user in keycloak_user.users : email => {
      email      = email
      user_id    = user.id
      first_name = user.first_name
      last_name  = user.last_name
      enabled    = user.enabled
    }
  }
}

output "user_credentials" {
  description = "Complete user credentials with passwords (SENSITIVE - store securely!)"
  value = {
    for email, user in keycloak_user.users : email => {
      username   = user.username
      email      = email
      password   = random_password.user_passwords[email].result
      temporary  = tobool(lookup(local.users_csv[index(local.users_csv.*.email, email)], "temporary_password", "true"))
      groups     = split(",", lookup(local.users_csv[index(local.users_csv.*.email, email)], "groups", ""))
    }
  }
  sensitive = true
}
