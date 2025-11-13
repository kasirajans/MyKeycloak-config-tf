variable "keycloak_url" {
  description = "The URL of the Keycloak server"
  type        = string
}

variable "keycloak_realm" {
  description = "The existing Keycloak realm to manage users in"
  type        = string
  default     = "consumer"
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

variable "realm_display_name" {
  description = "Display name for the realm"
  type        = string
  default     = "Consumer Realm"
}

variable "realm_display_name_html" {
  description = "HTML display name for the realm"
  type        = string
  default     = "<b>Consumer Portal</b>"
}


