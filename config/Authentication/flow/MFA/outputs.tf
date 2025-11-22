output "mfa_browser_flow_id" {
  description = "ID of the custom MFA browser authentication flow."
  value       = keycloak_authentication_flow.mfa_browser.id
}

output "mfa_webauthn_execution_id" {
  description = "ID of the WebAuthn MFA execution."
  value       = keycloak_authentication_execution.mfa_webauthn.id
}
