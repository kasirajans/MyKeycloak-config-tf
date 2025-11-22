output "mfa_browser_flow_id" {
  description = "ID of the custom MFA browser authentication flow."
  value       = keycloak_authentication_flow.mfa_browser.id
}

output "authentication_executions" {
  description = "Map of all authentication executions with their IDs."
  value = {
    for key, execution in keycloak_authentication_execution.executions : key => {
      id            = execution.id
      authenticator = execution.authenticator
      requirement   = execution.requirement
    }
  }
}

output "authentication_execution_ids" {
  description = "List of all authentication execution IDs."
  value       = [for execution in keycloak_authentication_execution.executions : execution.id]
}

output "required_actions" {
  description = "Map of all required actions with their IDs."
  value = {
    for key, action in keycloak_required_action.actions : key => {
      id             = action.id
      alias          = action.alias
      enabled        = action.enabled
      default_action = action.default_action
    }
  }
}
