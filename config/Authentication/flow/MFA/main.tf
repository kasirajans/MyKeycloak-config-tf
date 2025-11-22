terraform {
  required_providers {
    keycloak = {
      source  = "mrparkers/keycloak"
      version = ">= 3.6.0"
    }
  }
}

provider "keycloak" {
  client_id = var.keycloak_client_id
  url       = var.keycloak_url
  username  = var.keycloak_username
  password  = var.keycloak_password
  realm     = var.keycloak_admin_realm
}

# Load MFA configuration from YAML file
locals {
  mfa_config = yamldecode(file("${path.module}/mfa.yml"))
}




# Create authentication flow from YAML configuration
resource "keycloak_authentication_flow" "mfa_browser" {
  realm_id    = var.keycloak_realm_id
  alias       = local.mfa_config.authenticationFlows[0].alias
  description = local.mfa_config.authenticationFlows[0].description
  provider_id = local.mfa_config.authenticationFlows[0].providerId
}

# Create authentication executions from YAML configuration
resource "keycloak_authentication_execution" "mfa_username_password" {
  realm_id          = var.keycloak_realm_id
  parent_flow_alias = keycloak_authentication_flow.mfa_browser.alias
  authenticator     = local.mfa_config.authenticationFlows[0].executions[0].authenticator
  requirement       = local.mfa_config.authenticationFlows[0].executions[0].requirement
}

resource "keycloak_authentication_execution" "mfa_webauthn" {
  realm_id          = var.keycloak_realm_id
  parent_flow_alias = keycloak_authentication_flow.mfa_browser.alias
  authenticator     = local.mfa_config.authenticationFlows[0].executions[1].authenticator
  requirement       = local.mfa_config.authenticationFlows[0].executions[1].requirement
}

# Create required action from YAML configuration
resource "keycloak_required_action" "webauthn_register" {
  realm_id       = var.keycloak_realm_id
  alias          = local.mfa_config.requiredActions[0].alias
  enabled        = local.mfa_config.requiredActions[0].enabled
  default_action = local.mfa_config.requiredActions[0].defaultAction
}
