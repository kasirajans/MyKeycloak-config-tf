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
