terraform {
  required_version = ">= 1.5"

  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.0"
    }
  }
}

# Credentials never hardcoded here. var.* defaults to null, which falls through to the
# provider's own KEYCLOAK_URL/KEYCLOAK_USER/KEYCLOAK_PASSWORD env var defaults — so both
# work: plain env vars, or terraform.tfvars (gitignored; see terraform.tfvars.example)
# for a persistent local value / future pipeline TF_VAR_* injection.
provider "keycloak" {
  client_id = "admin-cli"
  url       = var.keycloak_url
  username  = var.keycloak_username
  password  = var.keycloak_password
}
