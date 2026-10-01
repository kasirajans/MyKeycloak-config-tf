# TODO: define input variables for the "client" module, including:
#   - client_id (string — already computed by the caller as <team>-<project>-<name>;
#     this module does not derive it)
#   - owner_team (string — set as a Keycloak client attribute for ownership tracking)
#   - project (string — set as a Keycloak client attribute; one team may own several)
#   - auth_pattern (string, one of "client-credentials" | "token-exchange" | "ciba")
#   - exchange_from (optional list(string) — client_ids that must be able to present
#     this client's client_id in their own token's aud claim; only meaningful when
#     auth_pattern = "token-exchange". This is audience wiring, not a permission grant.)
#   - aud (optional string — restricts issued/exchanged tokens to one resources/ entry)
