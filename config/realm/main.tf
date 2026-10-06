locals {
  realms_data = yamldecode(file("${path.module}/realms.yml"))
  realms      = { for r in local.realms_data.realms : r.realm => r }

  # Mail servers, defined once under smtp_servers: in realms.yml and picked per realm by
  # name (smtp: <name>). An unknown name fails here with "key not found".
  smtp_servers = try(local.realms_data.smtp_servers, {})
}

module "realm" {
  source   = "../../modules/realm"
  for_each = local.realms

  realm        = each.value.realm
  enabled      = each.value.enabled
  display_name = try(each.value.display_name, null)

  registration_allowed     = try(each.value.registration_allowed, null)
  reset_password_allowed   = try(each.value.reset_password_allowed, null)
  remember_me              = try(each.value.remember_me, null)
  verify_email             = try(each.value.verify_email, null)
  login_with_email_allowed = try(each.value.login_with_email_allowed, null)
  ssl_required             = try(each.value.ssl_required, null)
  access_token_lifespan    = try(each.value.access_token_lifespan, null)

  smtp_server   = try(each.value.smtp, null) != null ? local.smtp_servers[each.value.smtp] : null
  smtp_password = try(each.value.smtp, null) != null ? lookup(var.smtp_passwords, each.value.smtp, null) : null
}
