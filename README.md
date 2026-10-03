# MyKeycloak-config-tf

Terraform-managed Keycloak configuration, organized around identity domains, reusable
modules, and a data/logic split that lets dev teams self-service AI agent client access
via merge request.

## Identity separation

```
                    Keycloak
                       |
     +-----------------+-----------------+
     |                 |                 |
     v                 v                 v
 customer      home-human-automation   ai-agent
  realm              realm               realm
     |                 |                 |
     |                 |                 +-- Gateway
     |                 |                 +-- personal-ai-agent
     |                 |                 +-- iot-agent
     |                 |                 +-- iot-security-agent
     |                 |                 +-- MCP / resource clients
     |                 |
     |                 +-- Human Users
     |                 +-- Human Apps (PKCE, role-based, minimal scopes)
     |
     +-- Customer Users / Apps (PKCE, role-based, minimal scopes)
```

AI use cases (personal agent, agent-to-agent, human-to-agent-to-agent, agent-to-MCP-to-tools)
are **not** separate realms — they're all clients inside the single `ai-agent` realm,
reached from the human realms through a gateway.

## Concepts

- **Realm** = trust/identity boundary.
- **Client** = an application, agent, gateway, or protected resource identity.
- **Client scope** = a reusable permission/claim definition.
- **Role** = a broader identity/administrative permission.
- **Gateway** = a runtime enforcement point, implemented in Keycloak as the client(s)
  under `app/aiAgent/gateway/` using Standard Token Exchange (RFC 8693).
- **Resource/audience registry** = `app/aiAgent/resources/` — the set of downstream
  MCP servers/APIs/agents a delegation token's `aud` claim may be restricted to.
- **Agent Registry** = a separate application, not modeled in Keycloak.

## Delegation model (human -> AI Gateway -> MCP Gateway -> MCP servers)

The AI Gateway and MCP Gateway are built and deployed outside this repo; this repo only
configures the Keycloak clients they authenticate as and exchange tokens through, using
Keycloak's Standard Token Exchange V2 (GA by default) and native CIBA grant:

1. A human authenticates in `customer` or `home-human-automation` and gets a subject token.
2. AI Gateway exchanges it for a token scoped to itself, then — for MCP-bound calls —
   exchanges again for a token targeted at MCP Gateway. Each exchange is a same-realm,
   client-to-client audience swap: Keycloak requires the subject_token to already carry
   the requesting client in its own `aud` claim; there is no separate admin permission
   gating this, so `exchange_targets` in `app/aiAgent/gateway/*.yaml` exists to drive
   correct audience/client-scope wiring, not to grant access by itself.
3. MCP Gateway exchanges again for a token whose `aud` is one specific entry from
   `app/aiAgent/resources/` (one MCP server), scoped to only what that call needs.
4. **Open decision, not yet resolved:** Keycloak's GA token exchange does not attach an
   `act`/`sub` claim identifying both the human and the agent at each hop. If the AI
   Gateway or MCP Gateway need that for audit/authorization, pick one of: Keycloak's
   experimental `may_act`-claim "Token Exchange Delegation" feature (opt-in, not GA), a
   custom protocol mapper that stamps an equivalent claim, or no token-level actor claim
   at all with the gateways logging the chain themselves instead.
5. Pure machine/digital-worker clients with no human ever in the chain use
   `client_credentials` instead (`auth_pattern: client-credentials`).
6. Scopes marked `requires_human_approval: true` in `app/aiAgent/scopes/` may only be
   held by a client declaring `auth_pattern: ciba`. Keycloak's CIBA grant handles the
   protocol; actually delivering the async approval to a device requires a custom
   `AuthenticationChannelProvider` SPI implementation (also outside this repo).

`app/customer/` and `app/homeAutomation/` clients are plain PKCE, role-based, minimal
scopes — they don't participate in this delegation chain themselves, only as its origin.

## Ownership

Every client tracks two axes: **team** (the CODEOWNERS/folder boundary — who's allowed
to request it) and **project** (a team-chosen app/product name — one team may run
several projects). Both are baked into the Keycloak client itself, not just this repo's
layout:

- `client_id` is always computed by the owning `main.tf` as `<team>-<project>-<name>`,
  never supplied directly by a request YAML — `team` comes from the folder path
  (`app/aiAgent/clients/<team>/`, or an explicit `owner_team` field for `app/customer`
  and `app/homeAutomation`, which aren't sharded by folder), so a request can't spoof a
  different owner just by editing a field.
- `owner_team` and `project` are also set as Keycloak custom client attributes, so
  ownership is visible/queryable directly in the Keycloak admin console and API, not
  only derivable by tracing back to this repo.
- `ci/policy/` checks for `(project, name)` collisions across sibling teams in addition
  to the schema-level shape checks.

## Layout

- `config/realm/` — realm-level configuration only, one consolidated root module for
  all realms (`customer`, `home-human-automation`, `ai-agent`), listed in one
  `realms.yml` rather than a directory per realm. Platform-owned, rarely touched.
- `config/idp-provider/` — identity provider trust relationships, same one-`.yml`-list
  convention. Low volume.
- `app/customer/`, `app/homeAutomation/` — PKCE clients + app-specific (client) roles
  for the human realms, embedded together in each `clients/<client_name>.yaml`.
  Role-based, minimal scopes, lower churn than `app/aiAgent`.
- `users/<realmName>/` (top-level, not under `app/`) — realm-wide identity concerns not
  tied to any one app: the actual resident/human identities (one `user.yml` per home
  under `users/home-human-automation/` — `home1/user.yml` today, listing all members
  under `users:` rather than one file per person; each home also a Keycloak Group
  auto-granted the `resident` role), global (realm) roles (`resident`, `guest`,
  `home-admin` — a member's `account_type: owner` also implies `home-admin`, `member` implies
  nothing extra), and references to Keycloak's own built-in IAM/admin roles.
  Owner-reviewed only, never self-service — real people's PII, unlike client/scope
  requests. Reads app-specific client role IDs from the matching `app/<realm-app>/`
  state via `terraform_remote_state`.
- `app/aiAgent/` — AI agent clients, high churn, onboarded via merge request:
  - `resources/` — API-provider owned. Registry of downstream audiences.
  - `scopes/`, `policies/` — API-provider owned. Fine-grained MCP scopes/authorization
    policies, which teams may request them, and which require human approval.
  - `gateway/` — platform-owned. The Agent Gateway's own client config.
  - `clients/<team>/` — dev-team self-service. One YAML file per client request,
    validated in CI before merge (see `ci/`).
- `modules/` — reusable Terraform modules (`realm`, `client`, `client-scope`, `role`,
  `user`, `group`, `policy`) consumed by `config/`, `app/`, and `users/`. `modules/client`
  is `auth_pattern`-aware (client-credentials / token-exchange / ciba).
- `ci/` — schema (`schemas/`) and policy (`policy/`) validation that gates self-service
  merge requests before they can be applied.
- `CODEOWNERS` — routes approval along the same trust boundary: platform/API-provider
  teams own `config/`, `modules/`, `app/aiAgent/{scopes,policies,resources,gateway}/`,
  and `ci/`; individual teams own their own `app/aiAgent/clients/<team>/` folder.

## State boundaries

Each of `app/aiAgent/{scopes,policies,resources,gateway}`, and each team folder under
`app/aiAgent/clients/`, is intended to become its own Terraform state (own backend) once
volume warrants it — this keeps `plan`/`apply` fast and a team's merge request from
refreshing state it doesn't own. Cross-state references go through
`terraform_remote_state` outputs, not shared state.

`config/realm/` is a deliberate exception: all realms share one state, since realms are
low-churn (create once, rarely touched again) — splitting them into isolated per-realm
states would just be repeated provider/backend boilerplate for little benefit.
