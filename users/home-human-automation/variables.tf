variable "keycloak_url" {
  type        = string
  default     = null
  description = "Keycloak instance URL. Falls back to the KEYCLOAK_URL env var if unset."
}

variable "keycloak_username" {
  type        = string
  default     = null
  description = "Keycloak admin username (password grant). Falls back to KEYCLOAK_USER if unset."
}

variable "keycloak_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "Keycloak admin password (password grant). Falls back to KEYCLOAK_PASSWORD if unset."
}

variable "realm_id" {
  type        = string
  description = "The home-human-automation realm's ID. TODO: wire via terraform_remote_state reading config/realm's realm_ids output once that's applied, instead of setting this by hand."
}
