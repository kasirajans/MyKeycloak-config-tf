locals {
  # One file per public (PKCE) client: <client_id>.yaml. The file name is the client_id,
  # matching how app/home-human-automation/<client_id>.yaml names that client's roles.
  # _example* files are documentation only and never applied.
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

  # Public: browser/mobile login with PKCE, no secret.
  access_type = "PUBLIC"

  root_url                        = try(each.value.root_url, null)
  valid_redirect_uris             = try(each.value.redirect_uris, [])
  valid_post_logout_redirect_uris = try(each.value.post_logout_redirect_uris, [])
  web_origins                     = try(each.value.web_origins, ["+"])
}

# The realm's OIDC discovery document (standard OpenID Connect metadata). Its URLs use
# Keycloak's configured public hostname, so they're the ones browsers and apps must use.
data "http" "oidc_discovery" {
  url = "${var.keycloak_url}/realms/${var.realm_id}/.well-known/openid-configuration"

  request_headers = {
    Accept = "application/json"
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Could not read the realm's OIDC discovery document (HTTP ${self.status_code})."
    }
  }
}

locals {
  oidc = jsondecode(data.http.oidc_discovery.response_body)
}
