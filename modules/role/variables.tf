variable "realm_id" {
  type        = string
  description = "The realm this role exists within."
}

variable "name" {
  type        = string
  description = "The name of the role."
}

variable "description" {
  type        = string
  default     = null
  description = "The description of the role."

  # Keycloak stores this in a varchar(255) column; longer values fail at apply with a 500.
  validation {
    condition     = var.description == null || length(var.description) <= 255
    error_message = "Role description must be 255 characters or fewer (Keycloak column limit)."
  }
}

variable "client_id" {
  type        = string
  default     = null
  description = "If set, this role is created as a client role attached to this client's internal ID, instead of a realm role."
}

variable "composite_roles" {
  type        = list(string)
  default     = null
  description = "Optional list of role IDs this role is composed of."
}
