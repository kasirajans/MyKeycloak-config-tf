variable "realm_id" {
  type        = string
  description = "The realm this group exists in."
}

variable "name" {
  type        = string
  description = "The group's name, e.g. a home/site name like \"home1\"."
}

variable "parent_id" {
  type        = string
  default     = null
  description = "Optional parent group ID, for nested groups. Omit for a root-level group."
}

variable "attributes" {
  type        = map(string)
  default     = {}
}

variable "role_ids" {
  type        = list(string)
  default     = []
  description = "Role IDs auto-granted to every member of this group (e.g. the \"resident\" role for a home's group), via keycloak_group_roles."
}
