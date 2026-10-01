variable "realm_id" {
  type        = string
  description = "The realm this client scope belongs to."
}

variable "name" {
  type        = string
  description = "The display name of this client scope, e.g. \"billing-mcp:read\"."
}

variable "description" {
  type        = string
  default     = null
  description = "The description of this client scope in the GUI."
}

variable "include_in_token_scope" {
  type        = bool
  default     = true
  description = "When true, this scope's name is added to the access token's \"scope\" property."
}

variable "audience" {
  type        = string
  default     = null
  description = "If set, the aud claim value (from a resources/ registry entry) to stamp onto tokens carrying this scope via a hardcoded-audience protocol mapper. Leave null for a scope that doesn't restrict audience."
}
