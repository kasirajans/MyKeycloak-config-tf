# Keycloak Provider Variables

variable "keycloak_url" {
  description = "Keycloak server URL"
  type        = string
  default     = "http://localhost:8080"
}

variable "keycloak_client_id" {
  description = "Keycloak admin client ID for Terraform"
  type        = string
  default     = "admin-cli"
}

variable "keycloak_username" {
  description = "Keycloak admin username"
  type        = string
  sensitive   = true
}

variable "keycloak_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

variable "keycloak_admin_realm" {
  description = "Keycloak admin realm"
  type        = string
  default     = "master"
}
