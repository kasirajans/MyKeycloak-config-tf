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
  type        = string
  default     = null
}

variable "first_name" {
  type        = string
  default     = null
}

variable "last_name" {
  type        = string
  default     = null
}

variable "attributes" {
  type        = map(string)
  default     = {}
  description = "Custom user attributes, e.g. { site = \"apartment\" } for app/homeAutomation/users/<site>/ ownership tracking."
}

variable "role_ids" {
  type        = list(string)
  default     = []
  description = "Role IDs (realm or client roles) to assign to this user via keycloak_user_roles."
}
