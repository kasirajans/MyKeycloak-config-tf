output "consumer_realm_id" {
  description = "ID of the consumer realm"
  value       = keycloak_realm.consumer.id
}

output "created_admin_users" {
  description = "Map of created admin usernames to their Keycloak user IDs"
  value = {
    for key, user in keycloak_user.users : user.username => user.id
    if user.realm_id == "master"
  }
}

output "created_consumer_users" {
  description = "Map of created consumer usernames to their Keycloak user IDs"
  value = {
    for key, user in keycloak_user.users : user.username => user.id
    if user.realm_id == keycloak_realm.consumer.id
  }
}

output "created_admin_groups" {
  description = "Map of created admin group names to their Keycloak group IDs"
  value = {
    for name, group in keycloak_group.admin_groups : name => group.id
  }
}

output "created_consumer_groups" {
  description = "Map of created consumer group names to their Keycloak group IDs"
  value = {
    for name, group in keycloak_group.consumer_groups : name => group.id
  }
}

output "total_user_count" {
  description = "Total number of users created across all realms"
  value       = length(keycloak_user.users)
}

output "admin_user_count" {
  description = "Number of admin users created in master realm"
  value       = length([for user in keycloak_user.users : user if user.realm_id == "master"])
}

output "consumer_user_count" {
  description = "Number of consumer users created in consumer realm"
  value       = length([for user in keycloak_user.users : user if user.realm_id == keycloak_realm.consumer.id])
}
