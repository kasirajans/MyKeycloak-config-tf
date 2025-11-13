variable "keycloak_url" {
  description = "The URL of the Keycloak server"
  type        = string
}

variable "keycloak_realm" {
  description = "The Keycloak realm to create clients in"
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

# PKCE Client Variables
variable "pkce_client_id" {
  description = "Client ID for PKCE application"
  type        = string
}

variable "pkce_client_name" {
  description = "Display name for PKCE client"
  type        = string
}

variable "pkce_redirect_uris" {
  description = "Valid redirect URIs for PKCE client"
  type        = list(string)
}

variable "pkce_web_origins" {
  description = "Valid web origins for PKCE client (CORS)"
  type        = list(string)
}

variable "access_token_lifespan" {
  description = "Access token lifespan in seconds for PKCE client"
  type        = string
  default     = "300"  # 5 minutes
}

variable "session_idle_timeout" {
  description = "Session idle timeout in seconds"
  type        = string
  default     = "1800"  # 30 minutes
}

variable "session_max_lifespan" {
  description = "Session max lifespan in seconds"
  type        = string
  default     = "36000"  # 10 hours
}

# M2M Client Variables
variable "m2m_client_id" {
  description = "Client ID for M2M application"
  type        = string
}

variable "m2m_client_name" {
  description = "Display name for M2M client"
  type        = string
}

variable "m2m_client_secret" {
  description = "Client secret for M2M application"
  type        = string
  sensitive   = true
}

variable "m2m_access_token_lifespan" {
  description = "Access token lifespan in seconds for M2M client"
  type        = string
  default     = "3600"  # 1 hour
}

variable "m2m_service_account_roles" {
  description = "List of realm roles to assign to M2M service account"
  type        = list(string)
  default     = []
}
