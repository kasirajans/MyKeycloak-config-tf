variable "realm" {
  type        = string
  description = "The name of the realm. Unique across Keycloak."
}

variable "enabled" {
  type        = bool
  default     = true
  description = "Whether the realm is enabled."
}

variable "display_name" {
  type        = string
  default     = null
  description = "Human-friendly display name for the realm."
}

# Feature toggles below all default to null, which lets the Keycloak provider apply its
# own default for that attribute — a realm.yml only needs to set the ones it wants to
# override. A browser/human realm (customer, home-human-automation) typically leaves
# most of these alone; an M2M/token-exchange-only realm (ai-agent) typically locks the
# login/self-service ones to false, since no client here ever drives a browser flow.

variable "registration_allowed" {
  type        = bool
  default     = null
  description = "Whether self-registration is allowed. Irrelevant (set false) for a realm with no browser login."
}

variable "reset_password_allowed" {
  type        = bool
  default     = null
  description = "Whether the forgot-password flow is allowed. Irrelevant (set false) for a realm with no browser login."
}

variable "remember_me" {
  type        = bool
  default     = null
}

variable "verify_email" {
  type        = bool
  default     = null
}

variable "login_with_email_allowed" {
  type        = bool
  default     = null
}

variable "ssl_required" {
  type        = string
  default     = null
  description = "\"none\" | \"external\" | \"all\". M2M/token-exchange traffic should still be TLS-only (\"all\")."
}

variable "access_token_lifespan" {
  type        = string
  default     = null
  description = "e.g. \"2m\". Keep short for an M2M/token-exchange realm — tokens are meant to be narrowly scoped and short-lived per hop."
}
