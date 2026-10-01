#!/usr/bin/env bash
# Scaffolds the initial MyKeycloak-config-tf structure. Structure only: every .tf/.yml/
# .json file is a TODO stub, EXCEPT ci/policy/validate_aiagent_requests.py, which is
# real, working Python (a plain script, not OPA/Rego, so it runs in any CI with no new
# DSL and no Terraform/Keycloak credentials). Idempotent: every stub-writing helper
# below — including readme_stub — skips a target file that already exists, full stop,
# regardless of its content. (An earlier version tried to sniff "is this still a stub"
# by checking for a leading "# TODO:" line; that had two real bugs — readme_stub was
# never guarded at all, and real example content that itself started with "# TODO:"
# was misdetected as a stub and overwritten. Plain existence-check has no such
# false-positive.) So re-running this script (e.g. to add a new realm) will NOT clobber
# real code/docs written after bootstrap. To intentionally reset one file back to a
# stub, delete it first, then re-run.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

skip_notice() {
  echo "skip (already exists): $1"
}

tf_main() {
  local name="$1"
  if [[ -f main.tf ]]; then skip_notice "$PWD/main.tf"; return 0; fi
  cat > main.tf <<EOF
# TODO: define Terraform resources for the "${name}" module.
EOF
}

tf_variables() {
  local name="$1"
  if [[ -f variables.tf ]]; then skip_notice "$PWD/variables.tf"; return 0; fi
  cat > variables.tf <<EOF
# TODO: define input variables for the "${name}" module.
EOF
}

tf_outputs() {
  local name="$1"
  if [[ -f outputs.tf ]]; then skip_notice "$PWD/outputs.tf"; return 0; fi
  cat > outputs.tf <<EOF
# TODO: define outputs for the "${name}" module.
EOF
}

yaml_stub() {
  local file="$1" name="$2"
  if [[ -f "$file" ]]; then skip_notice "$PWD/$file"; return 0; fi
  cat > "$file" <<EOF
# TODO: define ${name}.
EOF
}

readme_stub() {
  local file="$1" title="$2" body="$3"
  if [[ -f "$file" ]]; then skip_notice "$PWD/$file"; return 0; fi
  cat > "$file" <<EOF
# ${title}

${body}
EOF
}

json_schema_stub() {
  local file="$1" title="$2" desc="$3"
  if [[ -f "$file" ]]; then skip_notice "$PWD/$file"; return 0; fi
  cat > "$file" <<EOF
{
  "\$schema": "http://json-schema.org/draft-07/schema#",
  "title": "${title}",
  "description": "TODO: ${desc}",
  "type": "object",
  "properties": {},
  "required": []
}
EOF
}

### config/realm — one realms.yml (a "realms:" list), platform-owned, rarely touched.
### One consolidated root module for all realms, not one directory per realm: realms are
### low-churn, so the isolated-state-per-directory principle elsewhere in this repo is
### deliberately not applied here — see config/realm/README.md once real code exists. ###
mkdir -p config/realm
yaml_stub config/realm/realms.yml \
  "the list of realms (customer, home-human-automation, ai-agent, ...) as a \"realms:\" list — each entry is one realm's settings (realm, enabled, display_name, plus the optional feature-toggle fields modules/realm/variables.tf exposes, e.g. registration_allowed, ssl_required). Adding a realm is one more list entry, not a new file"
(cd config/realm && tf_main "realm (reads realms.yml via for_each, calls modules/realm once per entry)")

### config/idp-provider — platform-owned, low volume, same realms.yml-style convention ###
mkdir -p config/idp-provider
readme_stub config/idp-provider/README.md "Identity Provider configuration" \
"Identity provider (IdP) trust relationships between realms and external/internal IdPs. Low volume — same pattern as config/realm/: one idp-providers.yml listing all providers, read by main.tf via for_each, rather than a directory per provider. TODO: not built yet."

### app/customer — PKCE, human, role-based, minimal scopes ###
mkdir -p app/customer/clients app/customer/roles
touch app/customer/clients/.gitkeep app/customer/roles/.gitkeep
(cd app/customer && tf_main "customer clients/roles" && tf_variables "customer clients/roles" && tf_outputs "customer clients/roles")
readme_stub app/customer/README.md "Customer applications" \
"PKCE clients and roles for the customer realm — role-based access with minimal scopes, lower churn than app/aiAgent. clients/*.yaml declares one PKCE client per app, including owner_team and project fields (no per-team folder sharding here, so both must be explicit in the file); client_id is computed by main.tf as <owner_team>-<project>-<name>, same ownership convention as app/aiAgent. roles/*.yaml declares one role per file. main.tf (platform-owned) reads both via for_each."

### app/homeAutomation — PKCE, human, role-based, minimal scopes. Only app-specific
### (client) roles live here, embedded in each client's own file — global/IAM roles and
### the actual users live in the top-level users/home-human-automation/ instead (see
### below), since those are a realm-wide identity concern, not tied to any one app. ###
mkdir -p app/homeAutomation/clients
cat > app/homeAutomation/clients/_example-client.yaml <<'EOF'
# TODO: client-level config for this app (e.g. redirect_uris, public_client, etc.) —
# actual client creation isn't implemented yet, so for now this client must already
# exist in Keycloak: it's looked up via a data source, by client_id = this file's name
# ("_example-client" here), not created by this module.
#
# appconfig: placeholder for that client-level config once client creation is built.
appconfig: {}

# roles: this client's own app-specific roles, scoped to it (keycloak_role with
# client_id set). Colocated here instead of a separate roles/client/<name>/ tree, since
# a client's roles are always 1:1 with that client.
roles:
  - name: admin
    description: Full control over this app.

  - name: viewer
    description: Read-only access to this app.
EOF

(cd app/homeAutomation && tf_main "homeAutomation clients/roles" && tf_variables "homeAutomation clients/roles" && tf_outputs "homeAutomation clients/roles")

readme_stub app/homeAutomation/README.md "Home/human automation applications" \
"PKCE clients and app-specific roles for the home-human-automation realm — same pattern as app/customer: role-based, minimal scopes, and the same owner_team + project ownership fields computing client_id as <owner_team>-<project>-<name>. Human identities here reach AI agents only through a gateway, never directly.

clients/<client_name>.yaml holds both that client's own config (appconfig:, once client creation is built) and its app-specific roles (roles:) in the same file, not a separate roles/client/<client_name>/ tree, since a client's roles are always 1:1 with that client.

Global (realm) roles, IAM/Keycloak-admin role references, and the actual residents/users all live in users/home-human-automation/ instead (top-level, realm-wide identity concern — see that directory's README), not here.

outputs.tf exposes the client role IDs as a role_ids map (<client_name>:<role> -> ID), which users/home-human-automation/ reads via terraform_remote_state."

### users/<realmName> — top-level, NOT under app/: realm-wide identity concerns, always
### owner-reviewed, never self-service (real human identities are PII, unlike app/aiAgent
### client requests). Built out for home-human-automation; the same shape applies to any
### other realm that later needs Terraform-managed users/global roles. ###
mkdir -p users/home-human-automation/roles/realm users/home-human-automation/roles/iam users/home-human-automation/home1
cat > users/home-human-automation/roles/realm/roles.yml <<'EOF'
# Global (realm) roles — apply across the whole home-human-automation realm, not scoped
# to any one app/client. Created as keycloak_role resources with no client_id.
roles:
  - name: resident
    description: >-
      Full resident access to home automation. Auto-granted to every member of a
      home's group (see main.tf) — do not also list this individually on a resident's
      own roles: unless they're not a group member for some reason.

  - name: guest
    description: Limited, temporary access.

  - name: admin
    description: >-
      Administrative access to a home's automation UI/settings. Assigned individually
      (roles: on that resident's own file) to whichever resident(s) administer a given
      home — not auto-granted by group membership, since not every resident of a home
      is its admin. Scoping "admin of which home" comes from combining this role with
      the admin's own home1/home2/... group membership; the consuming app must check
      both claims together — Keycloak grants the role and records the membership, it
      doesn't fuse them into one permission on its own.
EOF
yaml_stub users/home-human-automation/roles/iam/roles.yml \
  "references to Keycloak's own built-in administrative roles — an \"iam_roles:\" list of role names (e.g. manage-users, realm-admin) on the realm's automatic realm-management client, looked up, never created"
cat > users/home-human-automation/home1/_example-user.yml <<'EOF'
# TODO: example data, ignored by main.tf (filename starts with "_example"). Copy this
# pattern into a real user.yml in this folder to define home1's members.
#
# One file per home (not one per person). "resident" is auto-granted to everyone here
# via home1's Keycloak group membership — never list it individually.
#
# account_type:
#   - owner  -> this home's admin. Automatically also gets the "admin" role (on top of
#               "resident" from group membership) — no need to list it separately.
#   - member -> a regular resident. No automatic extra role beyond "resident".
#
# roles: (optional) — any ADDITIONAL grants beyond what account_type already implies,
# e.g. "iam:manage-users" or a client-specific "<client_name>:<role>" (the latter
# defined inline in app/homeAutomation/clients/<client_name>.yaml, read read-only here
# via terraform_remote_state).
users:
  - username: owner
    email: owner@example.com
    account_type: owner
    enabled: true

  - username: wife
    email: wife@example.com
    account_type: member
    enabled: true

  - username: child
    email: child@example.com
    account_type: member
    enabled: true
EOF
(cd users/home-human-automation && tf_main "users/home-human-automation (creates realm roles + looks up iam roles locally, reads app-specific client role_ids from app/homeAutomation/ via terraform_remote_state, creates one keycloak_group per home folder with the resident role auto-granted via keycloak_group_roles plus a keycloak_group_memberships listing that home's members, then reads each home's user.yml via for_each, flattening its users: list into individual records — account_type: owner also implies the admin role, member implies nothing extra beyond resident — and resolving each member's roles against the combined map)" \
  && tf_variables "users/home-human-automation" && tf_outputs "users/home-human-automation")
readme_stub users/home-human-automation/README.md "users/home-human-automation" \
"Realm-wide identity concerns for the home-human-automation realm, kept separate from app/homeAutomation/ (application-level clients and app-specific roles only). Owns: the actual members (one user.yml per home, not one file per person — home1 today, add siblings like home2, office later; owner-reviewed only, never self-service — see CODEOWNERS), one Keycloak Group per home (auto-granted the resident role, membership derived from each home's user.yml), global (realm) roles (roles/realm/roles.yml: resident, guest, admin), and IAM/Keycloak-admin role references (roles/iam/roles.yml, looked up on the realm's built-in realm-management client, never created).

Each member declares account_type: owner or member, not a raw role name — owner automatically also gets admin (this home's admin), member gets nothing extra beyond resident. Scoping admin of which home is the combination of the admin role plus that person's home-group membership — the consuming app must check both claims together, Keycloak doesn't fuse them into one permission on its own. Known gap: group membership isn't included in an issued token by default (needs a Group Membership protocol mapper on a client scope, not configured yet — see this directory's README).

A member's optional roles: list can reference iam:<role> or an app-specific client role defined inline in app/homeAutomation/clients/<client_name>.yaml's roles: key — read read-only here via terraform_remote_state, since those are tied to that app's own client, not a realm-wide concern.

Apply order: config/realm/ (creates the realm) -> app/homeAutomation/ (creates clients + client-specific roles this state reads) -> here."

### app/aiAgent — high-churn, self-service via MR: data/logic split ###
mkdir -p app/aiAgent/scopes app/aiAgent/policies app/aiAgent/resources app/aiAgent/gateway app/aiAgent/clients app/aiAgent/tests
touch app/aiAgent/tests/.gitkeep

# resources/ — API-provider owned: registry of downstream resources/audiences (MCP servers,
# APIs, other agents) that a delegation token can be scoped to via the `aud` claim.
(cd app/aiAgent/resources && yaml_stub "_example-resource.yaml" \
  "one downstream resource/audience: resource_id, the aud claim value Keycloak issues for it, the owning team/API provider, and (for MCP) the server URL. scopes/ reference resource_id instead of a free-text aud, so ci/policy can check both exist together" \
  && tf_main "aiAgent resources (registry, feeds aud values into token-exchange / client-scope config)" \
  && tf_variables "aiAgent resources" && tf_outputs "aiAgent resources")

# scopes/ — API-provider owned: defines fine-grained MCP scopes + which teams may request them
(cd app/aiAgent/scopes && yaml_stub "_example-mcp-server.yaml" \
  "the fine-grained scopes exposed by one MCP server/API: scope name, description, resource_id (must match an entry in app/aiAgent/resources/), allowed_requesters (teams), and requires_human_approval (bool — if true, only clients declaring auth_pattern: ciba in their request may hold this scope)" \
  && tf_main "aiAgent scopes" && tf_variables "aiAgent scopes" && tf_outputs "aiAgent scopes")

# policies/ — API-provider owned: authorization policies per resource server
(cd app/aiAgent/policies && yaml_stub "_example-resource-server.yaml" \
  "the authorization policies/permissions for one resource server" \
  && tf_main "aiAgent policies" && tf_variables "aiAgent policies" && tf_outputs "aiAgent policies")

# gateway/ — API-provider/platform owned: Keycloak client config for the two gateways
# being built outside this repo (AI Gateway, MCP Gateway). This directory does NOT model
# gateway behavior/code — only the Keycloak-side client(s) each gateway authenticates as
# and exchanges tokens through. Topology: AI Gateway -> MCP Gateway -> MCP servers.
mkdir -p app/aiAgent/gateway
(cd app/aiAgent/gateway && \
  yaml_stub "ai-gateway.yaml" \
    "the ai-gateway client: client_id, and exchange_targets (app/aiAgent client_ids or the mcp-gateway client this client is allowed to request a token exchange toward — see README.md for how Keycloak actually enforces this, since it is NOT a fine-grained admin permission)" && \
  yaml_stub "mcp-gateway.yaml" \
    "the mcp-gateway client: client_id, and exchange_targets (resource_id values from app/aiAgent/resources/ — the individual MCP servers this gateway fronts)" && \
  tf_main "aiAgent gateway (configures the ai-gateway and mcp-gateway Keycloak clients + token exchange settings)" \
  && tf_variables "aiAgent gateway" && tf_outputs "aiAgent gateway")
readme_stub app/aiAgent/gateway/README.md "Gateway Keycloak clients (ai-gateway, mcp-gateway)" \
"Keycloak client config for the two gateways built and deployed outside this repo:
ai-gateway (entry point for human-to-agent and A2A traffic) and mcp-gateway (fronts the
individual MCP servers, only ever called by ai-gateway). This directory configures
Terraform/Keycloak resources only — the gateways' own code/deployment lives elsewhere.

Real Keycloak mechanics (Standard Token Exchange V2, GA by default) — corrected from an
earlier draft that assumed a fine-grained 'permitted to exchange to' permission, which
does NOT exist for V2:
- A client can only exchange a subject_token for a new token targeted at a different
  client in the SAME realm; no user impersonation, no external-token exchange.
- The subject_token presented must already carry the requesting client (ai-gateway, or
  mcp-gateway) in its own aud claim — that requirement, not an admin permission, is what
  restricts who can exchange through whom. exchange_targets in ai-gateway.yaml /
  mcp-gateway.yaml above drives the aud/client-scope wiring that makes this true, plus
  optional Client Policies for extra conditions.
- Keycloak's GA token exchange does NOT add an act/sub delegation claim identifying both
  the human and the agent. If that's a hard requirement, evaluate Keycloak's
  experimental, opt-in 'Token Exchange Delegation' feature (may_act claim — not GA, can
  change) versus writing a custom protocol mapper to stamp an equivalent claim yourself.
  This is an open decision — do not assume either exists until it's built and tested."

# clients/ — dev-team self-service, sharded per team folder. Ownership is two axes:
# team (the folder / CODEOWNERS boundary) and project (a team-chosen app name — one team
# can own several projects). Both get baked into the resulting Keycloak client so
# ownership is visible/queryable in Keycloak itself, not just in this repo's directory
# layout.
mkdir -p "app/aiAgent/clients/_example-team"
(cd "app/aiAgent/clients/_example-team" && yaml_stub "_example-client.yaml" \
  "one AI agent client request: project (kebab-case app/product name — the team owns this axis explicitly since one team may run several projects), name (short client name within that project), description, auth_pattern (token-exchange | client-credentials | ciba — see ci/schemas/client.schema.json), and requested scopes (must be allow-listed for this team in app/aiAgent/scopes/, and if a scope has requires_human_approval: true, auth_pattern must be ciba). Do NOT include client_id — main.tf computes it as <team>-<project>-<name> from the folder + these fields, so it can't drift from the declared owner")
(cd app/aiAgent/clients && tf_main "aiAgent clients (reads clients/**/*.yaml via for_each; computes client_id = <team>-<project>-<name> from the folder name + each YAML's project/name fields, and passes owner_team + project into modules/client for the Keycloak-side attributes)" \
  && tf_variables "aiAgent clients" && tf_outputs "aiAgent clients")
readme_stub app/aiAgent/clients/README.md "AI agent client requests (self-service)" \
"One subdirectory per team. Add a <client>.yaml file in your team's folder to request a new AI agent client; do not edit main.tf. Declare project and name in the YAML — client_id is always computed as <team>-<project>-<name> (team taken from the folder you're filed under, never from the YAML itself), so ownership can't be spoofed by editing a field. CI validates the YAML shape (ci/schemas/) and that every requested scope is allow-listed for your team, its resource_id exists in app/aiAgent/resources/, and (if the scope requires human approval) that this client declares auth_pattern: ciba (ci/policy/) — all before a merge request can land. As a team's client count grows, its folder can be split into its own Terraform state so its MRs only plan its own slice."

readme_stub app/aiAgent/README.md "AI Agent applications" \
"Client, scope, resource, and policy definitions for the AI agent identities living in the ai-agent realm: personal-ai-agent, iot-agent, iot-security-agent, and MCP/resource clients.

- resources/, scopes/, policies/, and gateway/ are API-provider/platform owned (see CODEOWNERS) — dev teams don't touch these.
- clients/<team>/ is dev-team self-service via merge request — see clients/README.md.

Delegation pattern (human -> agent -> agent/MCP) follows OAuth 2.0 Token Exchange (RFC 8693): a human's token is exchanged at the gateway/ for a short-lived delegation token (sub=human, act.sub=agent, scope narrowed, aud=one resources/ entry), re-exchanged with a narrower scope/aud at each further hop. Pure machine/digital-worker clients that never have a human in the chain use client_credentials instead; sensitive actions require CIBA (client-initiated backchannel authentication) approval — see each client's auth_pattern.

This directory owns application-level config only — realm-level config lives in config/realm/ai-agent."

### modules/{realm,client-scope,role,user,policy,group} ###
for mod in realm client-scope role user policy group; do
  dir="modules/${mod}"
  mkdir -p "$dir"
  (cd "$dir" && tf_main "${mod}" && tf_variables "${mod}" && tf_outputs "${mod}")
done

### modules/client — generic client module, but callers pass auth_pattern so it can
### configure Keycloak-native delegation flows instead of being a flat OAuth client ###
mkdir -p modules/client
if [[ -f modules/client/main.tf ]]; then
  skip_notice "modules/client/{main,variables,outputs}.tf"
else
cat > modules/client/main.tf <<'EOF'
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
EOF
cat > modules/client/variables.tf <<'EOF'
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
EOF
cat > modules/client/outputs.tf <<'EOF'
# TODO: define outputs for the "client" module.
EOF
fi

### ci/ — self-service guardrails: schema validation + policy validation ###
mkdir -p ci/schemas ci/policy
json_schema_stub ci/schemas/client.schema.json "AI Agent Client Request" \
"define the allowed fields for a self-service client request: project (required, kebab-case pattern — the app/product this client belongs to; a team may declare several distinct projects across its files), name (required, kebab-case — short client name within that project), description, requested_scopes, redirect_uris, and auth_pattern (enum: client-credentials | token-exchange | ciba — declares which Keycloak delegation flow this client uses; drives the checks in ci/policy/). additionalProperties: false, and explicitly forbid a client_id field — it is always computed by main.tf as <team>-<project>-<name> (team from the folder path, never from requester-supplied data) so ownership can't be spoofed. Keep this narrow — real access control is enforced by ci/policy, not by this schema."
json_schema_stub ci/schemas/scope.schema.json "MCP Scope Definition" \
"define the shape of a scope definition file: scope name, description, resource_id (must reference an entry in app/aiAgent/resources/), allowed_requesters (teams), and requires_human_approval (bool)."
json_schema_stub ci/schemas/policy.schema.json "Authorization Policy Definition" \
"define the shape of an authorization policy/permission definition for a resource server."
json_schema_stub ci/schemas/resource.schema.json "Downstream Resource / Audience Registry Entry" \
"define the shape of a resource registry entry: resource_id, aud (the audience claim value Keycloak issues tokens for), owning team/API provider, and (for MCP) the server URL. This is the registry app/aiAgent/scopes/*.yaml resource_id fields must resolve against."
json_schema_stub ci/schemas/user.schema.json "Home Automation User" \
"define the allowed fields for a resident/user entry under app/homeAutomation/users/<site>/: username (required), email (optional), roles (required list, each must reference an existing app/homeAutomation/roles/*.yaml file name), enabled (bool). additionalProperties: false; no site field — site is always taken from the folder path. Unlike client.schema.json, this isn't gating self-service access (users/ is owner-reviewed, not self-service) — it exists to catch structural/typo mistakes before apply."
cat > ci/policy/validate_aiagent_requests.py <<'EOF'
#!/usr/bin/env python3
"""Validate app/aiAgent/clients/**/*.yaml requests before merge.

Plain script, not OPA/Rego: run directly in any CI (GitHub Actions, GitLab CI, ...) with
no Terraform init/plan and no Keycloak credentials, since it only reads this repo's YAML.
Exits non-zero and prints every violation found (not just the first) if any request:
  1. lists a scope in requested_scopes that app/aiAgent/scopes/*.yaml doesn't define, or
     whose allowed_requesters doesn't include the requesting team;
  2. references (via a scope) a resource_id with no matching entry in
     app/aiAgent/resources/*.yaml;
  3. requests a scope with requires_human_approval: true while its own auth_pattern
     isn't "ciba";
  4. declares auth_pattern: token-exchange while its computed client_id isn't listed in
     any app/aiAgent/gateway/*.yaml exchange_targets;
  5. declares a (project, name) pair already used by another team's request (client_id
     is <team>-<project>-<name>; team differs today, but identical project/name pairs
     across teams are almost always a copy-paste mistake and would collide if a team
     folder were ever renamed).

TODO: this only checks the relations above; it does not yet validate against
ci/schemas/*.json for basic shape (required fields, kebab-case, additionalProperties).
Add a jsonschema-based pass once those schemas are filled in.
"""
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
CLIENTS_DIR = ROOT / "app/aiAgent/clients"
SCOPES_DIR = ROOT / "app/aiAgent/scopes"
RESOURCES_DIR = ROOT / "app/aiAgent/resources"
GATEWAY_DIR = ROOT / "app/aiAgent/gateway"


def load_yaml_files(directory, skip_names=frozenset()):
    docs = []
    if not directory.is_dir():
        return docs
    for path in sorted(directory.glob("*.yaml")):
        if path.name in skip_names or path.name.startswith("_example"):
            continue
        with path.open() as f:
            data = yaml.safe_load(f) or {}
        docs.append((path, data))
    return docs


def load_client_requests():
    requests = []
    if not CLIENTS_DIR.is_dir():
        return requests
    for team_dir in sorted(p for p in CLIENTS_DIR.iterdir() if p.is_dir()):
        team = team_dir.name
        for path in sorted(team_dir.glob("*.yaml")):
            if path.name.startswith("_example"):
                continue
            with path.open() as f:
                data = yaml.safe_load(f) or {}
            data["_team"] = team
            data["_path"] = path
            requests.append(data)
    return requests


def main():
    errors = []

    scopes = {}
    for path, doc in load_yaml_files(SCOPES_DIR):
        for scope in doc.get("scopes", []):
            scopes[scope["name"]] = scope

    resources = {doc.get("resource_id") for _, doc in load_yaml_files(RESOURCES_DIR)}

    exchange_targets = set()
    for path, doc in load_yaml_files(GATEWAY_DIR):
        exchange_targets.update(doc.get("exchange_targets", []))

    seen_project_name = {}
    requests = load_client_requests()

    for req in requests:
        team = req["_team"]
        path = req["_path"]
        project = req.get("project")
        name = req.get("name")
        auth_pattern = req.get("auth_pattern")
        client_id = f"{team}-{project}-{name}"

        # rule 5: (project, name) collision across teams
        key = (project, name)
        if key in seen_project_name and seen_project_name[key] != team:
            errors.append(
                f"{path}: (project={project!r}, name={name!r}) already used by team "
                f"'{seen_project_name[key]}' — pick a different project/name"
            )
        else:
            seen_project_name[key] = team

        # rule 4: token-exchange clients must be a registered exchange target
        if auth_pattern == "token-exchange" and client_id not in exchange_targets:
            errors.append(
                f"{path}: auth_pattern is 'token-exchange' but computed client_id "
                f"'{client_id}' is not listed in any app/aiAgent/gateway/*.yaml "
                f"exchange_targets"
            )

        # rules 1-3: each requested scope
        for scope_name in req.get("requested_scopes", []):
            scope = scopes.get(scope_name)
            if scope is None:
                errors.append(f"{path}: requested scope '{scope_name}' is not defined "
                              f"in app/aiAgent/scopes/")
                continue
            if team not in scope.get("allowed_requesters", []):
                errors.append(f"{path}: team '{team}' is not in allowed_requesters for "
                              f"scope '{scope_name}'")
            if scope.get("resource_id") not in resources:
                errors.append(f"{path}: scope '{scope_name}' references resource_id "
                              f"'{scope.get('resource_id')}', which has no matching "
                              f"entry in app/aiAgent/resources/")
            if scope.get("requires_human_approval") and auth_pattern != "ciba":
                errors.append(f"{path}: scope '{scope_name}' requires human approval, "
                              f"but this client's auth_pattern is {auth_pattern!r}, "
                              f"not 'ciba'")

    if errors:
        print(f"aiAgent client request validation failed ({len(errors)} issue(s)):",
              file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    print(f"OK — validated {len(requests)} aiAgent client request(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
EOF
cat > ci/policy/requirements.txt <<'EOF'
pyyaml
EOF
readme_stub ci/README.md "CI validation" \
"Guardrails for self-service merge requests under app/aiAgent/clients/ and app/customer|homeAutomation/clients/. schemas/ validates request YAML shape (including each client's declared auth_pattern) — TODO, still stub schemas. policy/validate_aiagent_requests.py is a plain Python script (not OPA/Rego) that validates that requested scopes/roles are ones the requesting team is allowed to ask for, that referenced resource_ids exist in app/aiAgent/resources/, and that human-approval-required scopes are only paired with auth_pattern: ciba — run it as \`pip install -r ci/policy/requirements.txt && python ci/policy/validate_aiagent_requests.py\` in any CI (GitHub Actions, GitLab CI, ...), no Terraform init/plan or Keycloak credentials needed since it only reads this repo's YAML. Both schema and script validation must run in CI before merge — this is the real enforcement point, not manual review of hand-written HCL."

### CODEOWNERS — routes approval along the trust boundary ###
if [[ -f CODEOWNERS ]]; then
  skip_notice "$PWD/CODEOWNERS"
else
cat > CODEOWNERS <<'EOF'
# TODO: replace placeholder teams below with real GitHub/GitLab team handles.

# Platform/security team owns realm + IdP config — never touched by self-service MRs.
/config/  @platform-team

# Platform owns reusable module logic.
/modules/  @platform-team

# API providers own scope, resource-registry, and policy definitions for AI agent
# access — dev teams request against these, they don't edit them.
/app/aiAgent/scopes/     @api-providers
/app/aiAgent/policies/   @api-providers
/app/aiAgent/resources/  @api-providers

# Platform owns the Agent Gateway's own client config (token-exchange / permitted
# exchange targets) — this is a security boundary, not a per-team request.
/app/aiAgent/gateway/  @platform-team

# Platform owns the module logic that reads client requests; dev teams own only their
# own request folder. TODO: add one line per onboarded team, e.g.:
# /app/aiAgent/clients/team-a/  @team-a
/app/aiAgent/clients/*.tf  @platform-team

/app/customer/       @platform-team
/app/homeAutomation/  @platform-team

# Real human identities (PII) and realm-wide roles — always owner-reviewed, never
# self-service, regardless of which realm or home (home1, future home2/office, ...)
# they belong to. Kept separate from app/ since these aren't app-specific.
/users/  @platform-team

# CI guardrails — schema/policy changes need platform review.
/ci/  @platform-team
EOF
fi

### top-level README ###
if [[ -f README.md ]]; then
  skip_notice "$PWD/README.md"
else
cat > README.md <<'EOF'
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
  `admin` — a member's `account_type: owner` also implies `admin`, `member` implies
  nothing extra), and references to Keycloak's own built-in IAM/admin roles.
  Owner-reviewed only, never self-service — real people's PII, unlike client/scope
  requests. Reads app-specific client role IDs from the matching `app/<realm-app>/` state via
  `terraform_remote_state`.
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
EOF
fi

echo "Scaffold complete."
