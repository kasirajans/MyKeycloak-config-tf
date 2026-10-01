# users/home-human-automation

Realm-wide identity concerns for the home-human-automation realm, kept separate from
`app/homeAutomation/` (which owns application-level clients and app-specific roles
only). This directory owns:

- **The actual residents** — one `user.yml` per home (`home1/user.yml` today, add
  siblings like `home2/`, `office/` as you expand), not one file per person: each
  `user.yml` lists that home's members under `users:`. Owner-reviewed only, never
  self-service — real human identities (PII) always go through the same review path as
  `config/realm/`, regardless of who administers a given home. See CODEOWNERS.
- **`account_type` on each member** — `owner` or `member`. `owner` automatically also
  gets the `admin` role (this home's admin) on top of `resident`; `member` gets nothing
  extra. An optional per-member `roles:` list adds further grants beyond that
  (`iam:<role>`, `<client_name>:<role>`) — you don't need to know Keycloak role names
  just to declare who owns a home.
- **One Keycloak Group per home**, named after the folder (e.g. `home1`) — every member
  listed in that home's `user.yml` becomes a group member (`keycloak_group_memberships`,
  derived automatically, no separate registry needed). The group is auto-granted the
  `resident` role (`keycloak_group_roles`), so `resident` is never listed on an
  individual member — it always comes from group membership.
- **Global (realm) roles** — `roles/realm/roles.yml`: `resident` (group-granted, see
  above), `guest`, and `admin`. `admin` only ever reaches a member via `account_type:
  owner` — not every member of a home is its owner, so it can't be a group-level grant.
  "Admin of which home" is the combination of the `admin` role plus that person's own
  home-group membership; **the consuming application must check both claims
  together** — Keycloak grants the role and records the membership as two separate
  facts, it doesn't fuse them into one "admin-of-home1-specifically" permission on its
  own.
- **IAM/Keycloak-admin role references** — `roles/iam/roles.yml`, what a user can do in
  Keycloak itself (e.g. `manage-users`), looked up on the realm's built-in
  `realm-management` client, never created.

A member's optional `roles:` list can reference `iam:<role>` for an IAM/admin
reference, or `<client_name>:<role>` for an app-specific client role — the latter is
**not owned here**. Client roles are defined inline in that client's own file,
`app/homeAutomation/clients/<client_name>.yaml`'s `roles:` key (app-level, since
they're inherently tied to that app's own client), and this state reads them read-only
via `terraform_remote_state`.

## Known gap: group membership isn't in the token yet

Keycloak does **not** include group membership in an issued token by default — it needs
an explicit "Group Membership" protocol mapper added to a client scope the requesting
client includes. That mapper isn't configured anywhere in this repo yet (client
creation itself, in `app/homeAutomation/`, is also still a stub — see that directory's
README). Until it is, a consuming app can't actually read "which home does this admin
belong to" from the token, even though the group and role both exist correctly in
Keycloak. Needs to be added once real client creation is built.

## Apply order

`config/realm/` (creates the realm itself) → `app/homeAutomation/` (creates clients and
client-specific roles this state reads) → here.
