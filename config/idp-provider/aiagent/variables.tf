variable "keycloak_url" {
  type        = string
  description = "Keycloak server URL"
}

variable "keycloak_client_id" {
  type        = string
  description = "Keycloak admin client ID"
  default     = "admin-cli"
}


variable "keycloak_username" {
  type        = string
  description = "Keycloak admin username"
  sensitive   = true
}

variable "keycloak_password" {
  type        = string
  description = "Keycloak admin password"
  sensitive   = true
}

variable "keycloak_admin_realm" {
  type        = string
  description = "Keycloak admin realm (usually 'master')"
  default     = "master"
}

variable "okta_client_secret" {
  type        = string
  description = "Okta application client secret (optional - only needed if not using pure JWKS validation)"
  sensitive   = true
  default     = ""  # Empty by default for token exchange via JWKS
}
