variable "keycloak_url" {
  description = "The URL of the Keycloak server"
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

# Realm Configuration
variable "realm_name" {
  description = "Name of the realm (e.g., 'sp-customer')"
  type        = string
  default     = "sp-customer"
}

variable "realm_display_name" {
  description = "Display name of the realm"
  type        = string
  default     = "Service Provider Customer"
}

variable "realm_display_name_html" {
  description = "HTML display name of the realm"
  type        = string
  default     = "<b>Service Provider Customer</b>"
}

# Login Settings
variable "login_with_email_allowed" {
  description = "Allow users to log in with email"
  type        = bool
  default     = true
}

variable "registration_allowed" {
  description = "Allow user self-registration"
  type        = bool
  default     = false
}

variable "registration_email_as_username" {
  description = "Use email as username during registration"
  type        = bool
  default     = true
}

variable "reset_password_allowed" {
  description = "Allow users to reset their password"
  type        = bool
  default     = true
}

variable "remember_me" {
  description = "Enable 'Remember Me' functionality"
  type        = bool
  default     = true
}

variable "verify_email" {
  description = "Require email verification"
  type        = bool
  default     = false
}

variable "edit_username_allowed" {
  description = "Allow users to edit their username"
  type        = bool
  default     = false
}

# Session Settings (in seconds)
variable "sso_session_idle_timeout" {
  description = "SSO session idle timeout in seconds"
  type        = number
  default     = 1800  # 30 minutes
}

variable "sso_session_max_lifespan" {
  description = "SSO session max lifespan in seconds"
  type        = number
  default     = 36000  # 10 hours
}

variable "offline_session_idle_timeout" {
  description = "Offline session idle timeout in seconds"
  type        = number
  default     = 2592000  # 30 days
}

variable "offline_session_max_lifespan" {
  description = "Offline session max lifespan in seconds"
  type        = number
  default     = 5184000  # 60 days
}

variable "access_token_lifespan" {
  description = "Access token lifespan in seconds"
  type        = number
  default     = 300  # 5 minutes
}

# Security Settings
variable "ssl_required" {
  description = "SSL requirement level (none, external, all)"
  type        = string
  default     = "external"
}

variable "password_policy" {
  description = "Password policy rules"
  type        = string
  default     = "upperCase(1) and length(8) and digits(1) and notUsername"
}

# Internationalization
variable "supported_locales" {
  description = "List of supported locales"
  type        = list(string)
  default     = ["en", "es", "fr", "de"]
}

variable "default_locale" {
  description = "Default locale"
  type        = string
  default     = "en"
}

# SMTP Settings (Optional)
variable "smtp_server_enabled" {
  description = "Enable SMTP server configuration"
  type        = bool
  default     = false
}

variable "smtp_host" {
  description = "SMTP server host"
  type        = string
  default     = ""
}

variable "smtp_port" {
  description = "SMTP server port"
  type        = string
  default     = "587"
}

variable "smtp_from" {
  description = "SMTP from email address"
  type        = string
  default     = ""
}

variable "smtp_from_display_name" {
  description = "SMTP from display name"
  type        = string
  default     = ""
}

variable "smtp_ssl" {
  description = "Enable SMTP SSL"
  type        = bool
  default     = false
}

variable "smtp_starttls" {
  description = "Enable SMTP STARTTLS"
  type        = bool
  default     = true
}

variable "smtp_username" {
  description = "SMTP authentication username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "smtp_password" {
  description = "SMTP authentication password"
  type        = string
  default     = ""
  sensitive   = true
}
