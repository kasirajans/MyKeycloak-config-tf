locals {
  # One file per private (confidential) client: <client_id>.yaml. The file name is the
  # client_id, matching how app/home-human-automation/<client_id>.yaml names that
  # client's roles. _example* files are documentation only and never applied.
  client_files = [for f in fileset(path.module, "*.yaml") : f if !startswith(f, "_example")]

  clients = {
    for f in local.client_files :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/${f}"))
  }
}

module "client" {
  source   = "../../../modules/client"
  for_each = local.clients

  realm_id    = var.realm_id
  client_id   = each.key
  name        = try(each.value.name, null)
  description = try(each.value.description, null)
  owner_team  = try(each.value.owner_team, null)
  project     = try(each.value.project, null)

  # Private: a backend that keeps a client secret (Keycloak generates it).
  access_type = "CONFIDENTIAL"

  # Default is a pure machine client (client credentials). Set standard_flow: true for
  # a server-side web app that also logs users in.
  service_accounts_enabled   = try(each.value.service_accounts, true)
  standard_flow_enabled      = try(each.value.standard_flow, false)
  pkce_code_challenge_method = try(each.value.standard_flow, false) ? "S256" : null

  root_url                        = try(each.value.root_url, null)
  valid_redirect_uris             = try(each.value.redirect_uris, [])
  valid_post_logout_redirect_uris = try(each.value.post_logout_redirect_uris, [])
  web_origins                     = try(each.value.web_origins, [])
}
