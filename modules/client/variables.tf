variable "realm_id" {
  type        = string
  description = "The realm this client belongs to."
}

variable "client_id" {
  type        = string
  description = "The client_id string apps use to identify themselves. Passed in already computed by the caller; this module does not derive it."
}

variable "name" {
  type        = string
  default     = null
  description = "Display name of the client in Keycloak."
}

variable "description" {
  type        = string
  default     = null
  description = "Description of the client in Keycloak."
}

variable "enabled" {
  type        = bool
  default     = true
  description = "Whether the client can be used."
}

variable "access_type" {
  type        = string
  description = "\"PUBLIC\" (browser/mobile app, PKCE, no secret) or \"CONFIDENTIAL\" (backend with a client secret)."

  validation {
    condition     = contains(["PUBLIC", "CONFIDENTIAL"], var.access_type)
    error_message = "access_type must be \"PUBLIC\" or \"CONFIDENTIAL\"."
  }
}

variable "standard_flow_enabled" {
  type        = bool
  default     = true
  description = "Enables the authorization code flow (user login via browser redirect)."
}

variable "service_accounts_enabled" {
  type        = bool
  default     = false
  description = "Enables the client-credentials grant (the client acts as itself). Ignored for PUBLIC clients."
}

variable "pkce_code_challenge_method" {
  type        = string
  default     = null
  description = "PKCE method for CONFIDENTIAL clients (\"S256\" or null). PUBLIC clients always use S256."
}

variable "root_url" {
  type        = string
  default     = null
  description = "Root URL prepended to relative redirect URIs."
}

variable "valid_redirect_uris" {
  type        = list(string)
  default     = []
  description = "Allowed redirect URIs after login. Required when standard_flow_enabled is true."
}

variable "valid_post_logout_redirect_uris" {
  type        = list(string)
  default     = []
  description = "Allowed redirect URIs after logout."
}

variable "web_origins" {
  type        = list(string)
  default     = []
  description = "Allowed CORS origins. \"+\" means: every origin of valid_redirect_uris."
}

variable "owner_team" {
  type        = string
  default     = null
  description = "Team that owns this client. Stored as a custom client attribute for ownership tracking."
}

variable "project" {
  type        = string
  default     = null
  description = "Project this client belongs to (one team may own several). Stored as a custom client attribute."
}

variable "extra_config" {
  type        = map(string)
  default     = {}
  description = "Any further custom client attributes."
}
