variable "realm_id" {
  type        = string
  description = "The realm the user belongs to."
}

variable "username" {
  type        = string
  description = "Unique username identifier."
}

variable "enabled" {
  type        = bool
  default     = true
  description = "Controls whether the user can log in."
}

variable "email" {
  type    = string
  default = null
}

variable "first_name" {
  type    = string
  default = null
}

variable "last_name" {
  type    = string
  default = null
}

variable "attributes" {
  type        = map(string)
  default     = {}
  description = "Custom user attributes. Each must be declared in the realm's user profile (or unmanaged attributes enabled); otherwise Keycloak 24+ silently drops it and every plan shows a change."
}

variable "role_ids" {
  type        = list(string)
  default     = []
  description = "Role IDs (realm or client roles) to assign to this user via keycloak_user_roles."
}

variable "set_initial_password" {
  type        = bool
  default     = false
  description = "Whether to set initial_password when the user is created. Kept separate from the (sensitive) password itself so it can drive the dynamic block."
}

variable "initial_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "Password set when the user is created. Only used if set_initial_password is true."
}

variable "temporary_password" {
  type        = bool
  default     = true
  description = "true forces the user to change initial_password at first login."
}
