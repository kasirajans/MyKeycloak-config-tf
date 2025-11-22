variable "keycloak_url" {
  description = "The URL of the Keycloak server"
  type        = string
}

variable "keycloak_client_id" {
  description = "Client ID for Keycloak authentication (typically 'admin-cli')"
  type        = string
  default     = "admin-cli"
}

variable "keycloak_username" {
  description = "Admin username for Keycloak authentication"
  type        = string
  sensitive   = true
}

variable "keycloak_password" {
  description = "Admin password for Keycloak authentication"
  type        = string
  sensitive   = true
}

variable "keycloak_admin_realm" {
  description = "Realm to authenticate against (usually 'master')"
  type        = string
  default     = "master"
}

variable "keycloak_realm_id" {
  description = "Realm Id to create config"
  type        = string
}