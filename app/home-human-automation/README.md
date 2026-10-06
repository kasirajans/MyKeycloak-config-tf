# Home/human automation applications

PKCE clients and app-specific roles for the home-human-automation realm — same pattern as app/customer: role-based, minimal scopes, and the same owner_team + project ownership fields computing client_id as <owner_team>-<project>-<name>. Human identities here reach AI agents only through a gateway, never directly.

## public/ and private/ — the clients themselves, one state each

Each is its own Terraform root with its own state file, both built from `modules/client/`. Add a `<client_id>.yaml` file (the file name is the `client_id`; see the `_example*` file in each folder):

- `public/` — **public** clients: browser/mobile apps that can't keep a secret. Authorization code flow with PKCE (S256), no client secret. Example: `app.yaml`.
- `private/` — **private (confidential)** clients: backends that keep a Keycloak-generated secret. Client credentials by default; `standard_flow: true` for a server-side web app that also logs users in. Read secrets with `terraform output -json client_secrets`.

## <client_name>.yaml — that client's own roles

`<client_name>.yaml` holds the app-specific roles (`roles:`) of a client created in `public/` or `private/` — not a separate `roles/client/<client_name>/` tree, since a client's roles are always 1:1 with that client. `<client_name>` is the file's name (its `client_id` string), looked up via a data source here.

Global (realm) roles, IAM/Keycloak-admin role references, and the actual residents/users all live in `users/home-human-automation/` instead (a top-level, realm-wide identity concern — see that directory's README) — not here, since those aren't specific to any one app/client.

`outputs.tf` exposes the client role IDs as a `role_ids` map (`<client_name>:<role>` -> ID), for reference. `users/home-human-automation/users/` doesn't read it: it looks client roles up by name in Keycloak.

## Apply order

`config/realm/` (creates the realm) first, then `public/` and `private/` (in any order), then this directory. `users/home-human-automation/users/` must be applied after this one, since the client roles it grants must already exist.
