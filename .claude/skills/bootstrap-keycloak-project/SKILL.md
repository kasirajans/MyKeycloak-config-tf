---
name: bootstrap-keycloak-project
description: One-time scaffold of the MyKeycloak-config-tf folder layout (config/, app/, modules/, ci/) with realm/domain separation for customer, home-human-automation, and ai-agent identities, plus a data/logic split for self-service client onboarding via merge request. Use only to lay down the initial empty structure in this repo; not for adding realms/apps/teams later and not for writing real Keycloak Terraform logic.
---

# Bootstrap: MyKeycloak-config-tf project structure

This skill scaffolds the initial directory/file layout for this repo. It creates
**structure only** — placeholder `.tf`/`.yml`/`.json` files with TODO markers, no
working Keycloak resource logic — with one deliberate exception:
`ci/policy/validate_aiagent_requests.py` is real, working Python (not OPA/Rego — a
plain script was chosen so it runs in any CI with no new DSL and no Terraform/Keycloak
credentials). Run this skill once, at the start of the project, on an empty (or
already-cleared) working tree.

## Architecture this scaffold encodes

**Identity model:**
- **Realm** = trust/identity boundary. Three realms: `customer`, `home-human-automation`,
  `ai-agent`. Do not create a separate realm per AI use case — all AI agent identities
  (personal agent, IoT agent, security agent, MCP/resource clients) live as **clients**
  inside the single `ai-agent` realm.
- **Client** = an application, agent, gateway, or protected resource identity within a realm.
- **Client scope** = a reusable permission/claim definition, shared across clients.
- **Role** = a broader identity/administrative permission.
- **Gateway** = a runtime enforcement point (human identities reach AI agents through a
  gateway, not directly).
- **Agent Registry** = a separate application, not something Keycloak models — do not
  scaffold this here.
- `config/` owns realm and identity-provider configuration only, platform-owned, rarely
  touched. `app/` owns application-level clients, scopes, and policies. Keep these
  separate — don't let realm YAML grow into a full AI-architecture config file.
- `config/realm/` and `config/idp-provider/` are each **one consolidated root module**
  (one `realms.yml` / `idp-providers.yml` list, one state), not a directory per realm or
  provider — a deliberate exception to the per-directory state-isolation principle
  elsewhere in this repo, justified by how low-churn realm/IdP config is. Merging the
  *Terraform state* this way is not the same as merging the *Keycloak realms themselves*
  into one — the three realms stay separate trust boundaries with separate settings;
  only the data files and state are consolidated.

**Self-service / MR governance model** (this is the part that shapes `app/aiAgent/`):
- AI-agent clients and their MCP scopes are high-churn and requested by dev teams via
  merge request, so `app/aiAgent/` splits **data from logic**:
  - `resources/`, `scopes/`, and `policies/` are **API-provider owned** — they define
    the registry of downstream audiences (`resources/`), what fine-grained MCP scopes
    exist and which teams may request them (`scopes/`), and authorization
    policies/permissions (`policies/`). Dev-team MRs never touch these.
  - `gateway/` is **platform owned** — the Agent Gateway's own Keycloak client config.
  - `clients/<team>/` is **dev-team self-service** — one YAML file per client request,
    sharded by team folder so a team's MR only ever plans/touches its own slice of state.
  - `main.tf` in each of those subdirs is owned by platform and reads the YAML via
    `for_each` — it doesn't change per request.
- `ci/schemas/` validates the *shape* of a request YAML (including each client's
  declared `auth_pattern`); `ci/policy/` validates that a requested scope is one the
  requesting team is actually allowed to ask for, that its `resource_id` resolves in
  `resources/`, and that human-approval-required scopes are only paired with
  `auth_pattern: ciba`. Both run in CI before merge — this is the real guardrail, not
  code review of hand-written HCL.
- `CODEOWNERS` routes approval: platform/API-provider teams own `config/`, `modules/`,
  `app/aiAgent/{scopes,policies,resources,gateway}/`, and `ci/`; individual teams own
  their own `app/aiAgent/clients/<team>/` folder.
- `app/customer/` and `app/homeAutomation/` are simpler — PKCE, role-based, minimal
  scopes, lower churn — so they get a flat `clients/` pattern without the
  scopes/policies/resources split or per-team sharding. Each client's app-specific
  roles are embedded in that same `clients/<client_name>.yaml` file (a `roles:` key
  alongside its `appconfig:`), not a separate `roles/client/<client_name>/` tree, since
  a client's roles are always 1:1 with that client.
- `users/<realmName>/` (top-level, not under `app/`) holds realm-wide identity concerns
  that aren't tied to any one application: the actual resident/human identities (one
  `user.yml` per home under `users/home-human-automation/` — `home1/user.yml` today,
  listing all of that home's members under `users:`, not one file per person; more
  homes can be added as sibling folders later), global (realm) roles
  (`roles/realm/roles.yml`: `resident`, `guest`, `admin`), and references to Keycloak's
  own built-in IAM/admin roles (`roles/iam/roles.yml`, looked up on the realm's
  automatic `realm-management` client, never created). This is the opposite governance
  choice from `clients/`: owner-reviewed only, never self-service, since these are real
  people's PII rather than app registrations — see CODEOWNERS. The home is inferred
  from the folder, same convention as `team` for `app/aiAgent/clients/<team>/`. Each
  home is also a **Keycloak Group** of the same name, membership derived automatically
  from that home's `user.yml`, and auto-granted the `resident` role — each member
  declares `account_type: owner` or `member` rather than a raw role name; `owner`
  automatically also gets `admin` (this home's admin), `member` gets nothing extra
  ("admin of which home" is the combination of the `admin` role and that person's own
  home-group membership, which the consuming app
  must check together — Keycloak doesn't fuse them into one permission itself). App-
  specific (client) roles stay embedded in `app/<realm-app>/clients/<client_name>.yaml`'s
  `roles:` key instead — `users/<realmName>/` reads those read-only via
  `terraform_remote_state`, since they're tied to that app's own client, not a
  realm-wide concern.

**Ownership tracking:** every client request tracks two axes — team (who's allowed to
request it; the folder under `app/aiAgent/clients/<team>/`, or an explicit `owner_team`
field for `app/customer`/`app/homeAutomation` since those aren't folder-sharded) and
project (a team-chosen app/product name; one team may run several). `client_id` is
always computed by the owning `main.tf` as `<team>-<project>-<name>`, never taken
directly from the request YAML, so ownership can't be spoofed by editing a field.
`owner_team` and `project` are also set as Keycloak custom client attributes so
ownership is queryable in Keycloak itself, not only derivable from this repo's layout.
`ci/policy/` additionally checks `(project, name)` doesn't collide across sibling teams.

**Delegation model** (human -> AI Gateway -> MCP Gateway -> MCP servers). The AI Gateway
and MCP Gateway are separate applications built and deployed outside this repo —
`app/aiAgent/gateway/` only configures the Keycloak clients they use, not gateway
behavior. Implemented on Keycloak-native features (verified against Keycloak's own
docs, not assumed):
- OAuth 2.0 Token Exchange, via Keycloak's **Standard Token Exchange V2** (GA by
  default, no feature flag). It only does same-realm client-to-client audience swaps —
  no user impersonation, no external-token exchange. Each hop (human->AI Gateway,
  AI Gateway->MCP Gateway, MCP Gateway->one `resources/` entry) is one such swap.
- What actually gates an exchange: the subject_token must already carry the requesting
  client in its own `aud` claim. **There is no "permitted to exchange to" admin
  permission for V2** — an earlier draft of this scaffold assumed one; it's wrong.
  `exchange_targets` in `app/aiAgent/gateway/{ai-gateway,mcp-gateway}.yaml` and
  `exchange_from` in `modules/client` exist to drive correct `aud`/client-scope wiring,
  not to grant access by themselves.
- Keycloak's GA token exchange does **not** add an `act`/`sub` delegation claim
  identifying both the human and the agent. This is a real, unresolved gap versus
  Ping's model — options are Keycloak's experimental, non-GA `may_act`-claim "Token
  Exchange Delegation" feature, a custom protocol mapper, or no actor claim at all with
  the gateways logging the chain themselves. Don't assume any of these is in place;
  it's an open decision for whoever builds the AI/MCP Gateways.
- Sensitive scopes (`requires_human_approval: true` in `scopes/*.yaml`) require a client
  with `auth_pattern: ciba` — Keycloak's CIBA grant is native and GA, but delivering the
  actual async approval to a device needs a custom `AuthenticationChannelProvider` SPI
  (also outside this repo; Keycloak ships the protocol, not a push service).
  Pure machine/digital-worker clients with no human in the chain use
  `auth_pattern: client-credentials`.

## Steps

1. Confirm the working tree is empty or the user has explicitly asked to (re)scaffold —
   the script only creates files via `cat >`, so re-running overwrites placeholders;
   check `git status` first if unsure.
2. Run the scaffold script:
   ```
   bash .claude/skills/bootstrap-keycloak-project/scaffold.sh
   ```
3. Report the resulting tree to the user (`git status --short` or
   `find . -not -path './.git*'`).
4. Remind the user this is structure-only: every `.tf`/`.yml`/`.json` file is a stub
   with a `TODO` comment — no real Keycloak resources, no working schema validation yet
   (`ci/policy/validate_aiagent_requests.py` is the one exception — it's real, runnable
   Python). The previous working Terraform (AIAgent client-scope module, MFA flow,
   idp-provider configs, etc.) still exists in git history prior to the working-tree
   deletion, and can be cherry-picked into the new module layout when ready — don't do
   this automatically.
5. Do not invoke this skill again for incremental work (new realm, new agent app, new
   team folder under `clients/`, new module) — that's normal file creation, not a
   re-bootstrap.
