# TODO: define the keycloak_openid_client resource(s) for this module, parameterized by
# var.auth_pattern:
#   - "client-credentials": standard service-account client, no token-exchange config.
#   - "token-exchange": enable standard token exchange (GA by default in current
#     Keycloak — no feature flag needed) and set up this client's audience/client-scope
#     mapping so that var.exchange_from clients legitimately receive this client_id in
#     their own token's aud claim. That aud-on-subject_token requirement is what Keycloak
#     actually checks at exchange time — there is NO separate "permitted to exchange to"
#     admin permission for standard (V2) token exchange; do not scaffold one. Add a
#     Client Policy resource here only if you need extra conditional restrictions beyond
#     the aud check.
#   - "ciba": set the CIBA grant on the client (native GA grant) plus wire it to an
#     AuthenticationChannelProvider SPI implementation for actually delivering the async
#     approval — Keycloak does not ship a push-notification backend, that SPI is custom
#     code living outside this repo, this module only flips the client-side grant on.
#
# Ownership tracking (var.owner_team, var.project): set them as Keycloak custom client
# attributes (the openid client resource's attributes/extra-config map — check the exact
# argument name for the Keycloak Terraform provider version in use) so ownership is
# visible/queryable directly on the client in Keycloak, not just inferable from this
# repo's folder layout. client_id itself is passed in already computed by the caller
# (<team>-<project>-<name>) — this module does not compute it, only sets attributes.
