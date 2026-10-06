variable "keycloak_url" {
  type        = string
  default     = null
  description = "Keycloak instance URL. Falls back to the KEYCLOAK_URL env var if unset here — set via terraform.tfvars locally, or -var/-var-file/TF_VAR_keycloak_url from a pipeline later."
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
  description = "Keycloak admin password (password grant). Falls back to KEYCLOAK_PASSWORD if unset. Never commit a real value — terraform.tfvars is gitignored; in a pipeline, inject this as a secret (TF_VAR_keycloak_password or -var), not a checked-in tfvars file."
}

variable "smtp_passwords" {
  type        = map(string)
  default     = {}
  sensitive   = true
  description = "SMTP login passwords, keyed by server name from config/smtp/smtp.yml. Never commit: set in terraform.tfvars (gitignored) or TF_VAR_smtp_passwords."
}
