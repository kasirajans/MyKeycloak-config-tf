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
  
  # Flatten executions for easier processing
  executions = flatten([
    for flow_idx, flow in local.mfa_config.authenticationFlows : [
      for exec_idx, execution in flow.executions : {
        flow_alias    = flow.alias
        execution_key = "${flow.alias}-${exec_idx}"
        authenticator = execution.authenticator
        requirement   = execution.requirement
        priority      = lookup(execution, "priority", exec_idx)
      }
    ]
  ])
  
  # Create map of required actions from YAML
  required_actions = {
    for idx, action in lookup(local.mfa_config, "requiredActions", []) : 
    action.alias => action
  }
}




# Create passwordless authentication flow from YAML configuration
resource "keycloak_authentication_flow" "mfa_browser" {
  realm_id    = var.keycloak_realm_id
  alias       = local.mfa_config.authenticationFlows[0].alias
  description = local.mfa_config.authenticationFlows[0].description
  provider_id = local.mfa_config.authenticationFlows[0].providerId
}

# Create authentication executions dynamically from YAML configuration
resource "keycloak_authentication_execution" "executions" {
  for_each = { for exec in local.executions : exec.execution_key => exec }

  realm_id          = var.keycloak_realm_id
  parent_flow_alias = keycloak_authentication_flow.mfa_browser.alias
  authenticator     = each.value.authenticator
  requirement       = each.value.requirement
}

# Create required actions dynamically from YAML configuration
resource "keycloak_required_action" "actions" {
  for_each = local.required_actions

  realm_id       = var.keycloak_realm_id
  alias          = each.value.alias
  enabled        = each.value.enabled
  default_action = lookup(each.value, "defaultAction", false)
  priority       = lookup(each.value, "priority", 10)
}
