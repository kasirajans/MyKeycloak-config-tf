# Home/human automation applications

PKCE clients and app-specific roles for the home-human-automation realm — same pattern as app/customer: role-based, minimal scopes, and the same owner_team + project ownership fields computing client_id as <owner_team>-<project>-<name>. Human identities here reach AI agents only through a gateway, never directly.

## clients/ — client config + that client's own roles, together

`clients/<client_name>.yaml` holds both that client's own config (`appconfig:`, once client creation is built) and its app-specific roles (`roles:`) in the same file — not a separate `roles/client/<client_name>/` tree, since a client's roles are always 1:1 with that client. `<client_name>` is the file's name (its `client_id` string), looked up via a data source, not created here (client creation itself isn't implemented yet).

Global (realm) roles, IAM/Keycloak-admin role references, and the actual residents/users all live in `users/home-human-automation/` instead (a top-level, realm-wide identity concern — see that directory's README) — not here, since those aren't specific to any one app/client.

`outputs.tf` exposes the client role IDs as a `role_ids` map (`<client_name>:<role>` -> ID), which `users/home-human-automation/` reads via `terraform_remote_state` to resolve residents' client-role references.

## Apply order

`config/realm/` (creates the realm) must be applied before this directory. `users/home-human-automation/` must be applied after this one, since it reads `role_ids` from here.
