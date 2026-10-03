#!/usr/bin/env bash
# Run Terraform across every root in dependency order, then list what each state manages.
#
# Usage: scripts/tf-all.sh [plan|apply|destroy|resources|outputs] [extra terraform args...]
#   plan       init + plan every root (default)
#   apply      init + apply every root in order, then print the resource table
#   destroy    destroy every root in reverse order
#   resources [filter]  list resources in each root's state (no changes)
#   table [filter]      one table of all resources: folder, type, name, realm, id
#   show [filter]       print every attribute of each resource (no changes)
#   outputs             show each root's outputs (no changes)
#
# filter is a case-insensitive substring of the resource address, e.g.
#   scripts/tf-all.sh resources keycloak_user
#   scripts/tf-all.sh show 'module.realm["customer"]'
#
# Credentials: a root's own terraform.tfvars wins; otherwise config/realm/terraform.tfvars
# is reused. KEYCLOAK_URL / KEYCLOAK_USER / KEYCLOAK_PASSWORD env vars also work.
# realm_id is filled from config/realm's realm_ids output unless TF_VAR_realm_id is set.
#
# Note: on a fresh setup, "plan" skips roots that read another root's state until that
# root has been applied once (e.g. users/home-human-automation needs app/homeAutomation).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACTION="${1:-plan}"
shift || true
EXTRA_ARGS=("$@")
# For resources/show, the first extra arg is a filter, not a terraform flag.
FILTER=""
case "$ACTION" in resources|show|table) FILTER="${1:-}" ;; esac

# "<dir>|<realm name for realm_id, or empty>" — order matters (dependencies first).
ROOTS=(
  "config/realm|"
  "app/customer|customer"
  "app/homeAutomation|home-human-automation"
  "users/home-human-automation|home-human-automation"
  "app/aiAgent/resources|ai-agent"
  "app/aiAgent/scopes|ai-agent"
  "app/aiAgent/policies|ai-agent"
  "app/aiAgent/gateway|ai-agent"
  "app/aiAgent/clients|ai-agent"
)

SHARED_TFVARS="$REPO_ROOT/config/realm/terraform.tfvars"

bold() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33m    %s\033[0m\n' "$*"; }

# Roots that are still TODO stubs have no resource/module/data blocks — skip them.
has_config() { grep -qE '^(resource|module|data) "' "$1"/*.tf 2>/dev/null; }

# Prints any local terraform_remote_state file this root reads that doesn't exist yet.
missing_remote_state() {
  local dir="$1" p
  grep -hE '^\s*path\s*=\s*".*\.tfstate"' "$dir"/*.tf 2>/dev/null \
    | sed -E 's/.*"(.*)".*/\1/; s#\$\{path\.module\}#'"$dir"'#' \
    | while read -r p; do [ -f "$p" ] || echo "$p"; done
}

realm_id_for() {
  local realm="$1"
  [ -z "$realm" ] && return 0
  terraform -chdir="$REPO_ROOT/config/realm" output -json realm_ids 2>/dev/null \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('$realm',''))" 2>/dev/null || true
}

var_args_for() {
  local dir="$1" realm="$2" id
  VAR_ARGS=()
  if [ ! -f "$dir/terraform.tfvars" ] && [ -f "$SHARED_TFVARS" ]; then
    VAR_ARGS+=("-var-file=$SHARED_TFVARS")
  fi
  if [ -n "$realm" ] && [ -z "${TF_VAR_realm_id:-}" ] \
      && grep -q 'variable "realm_id"' "$dir"/variables.tf 2>/dev/null; then
    id="$(realm_id_for "$realm")"
    if [ -n "$id" ]; then
      VAR_ARGS+=("-var=realm_id=$id")
    else
      warn "realm_id for '$realm' not found — apply config/realm first or set TF_VAR_realm_id"
    fi
  fi
}

# State addresses in a root, narrowed to those containing FILTER (case-insensitive) if set.
state_addresses() {
  terraform -chdir="$1" state list 2>/dev/null | { grep -iF -- "${FILTER:-}" || true; }
}

list_resources() {
  local dir="$1" addrs
  if ! terraform -chdir="$dir" state list >/dev/null 2>&1; then
    warn "no state yet"
    return 0
  fi
  addrs="$(state_addresses "$dir")"
  if [ -z "$addrs" ]; then
    echo "    0 resource(s)${FILTER:+ matching '$FILTER'}"
    return 0
  fi
  echo "    $(echo "$addrs" | wc -l | tr -d ' ') resource(s)${FILTER:+ matching '$FILTER'}:"
  echo "$addrs" | sed 's/^/      /'
}

# One table across all roots: FOLDER | TYPE | NAME | REALM | ID (managed resources only).
print_table() {
  local entry rel dir
  for entry in "${ROOTS[@]}"; do
    rel="${entry%%|*}"; dir="$REPO_ROOT/$rel"
    has_config "$dir" || continue
    terraform -chdir="$dir" state list >/dev/null 2>&1 || continue
    printf '%s\t' "$rel"
    terraform -chdir="$dir" show -json | tr -d '\n'
    echo
  done | FILTER="$FILTER" python3 -c '
import json, os, sys

flt = os.environ.get("FILTER", "").lower()
rows = []

def walk(folder, mod):
    for r in mod.get("resources", []):
        if r.get("mode") != "managed" or flt not in r["address"].lower():
            continue
        v = r.get("values") or {}
        name = next((v[k] for k in ("username", "client_id", "name", "alias", "realm") if v.get(k)), r["name"])
        realm = v.get("realm_id") or v.get("realm") or ""
        rows.append((folder, r["type"].removeprefix("keycloak_"), str(name), str(realm), str(v.get("id", ""))))
    for child in mod.get("child_modules", []):
        walk(folder, child)

for line in sys.stdin:
    folder, _, raw = line.rstrip("\n").partition("\t")
    walk(folder, json.loads(raw).get("values", {}).get("root_module", {}))

if not rows:
    print("No resources" + (f" matching {flt!r}" if flt else "") + ".")
    sys.exit(0)

head = ("FOLDER", "TYPE", "NAME", "REALM", "ID")
w = [max(len(x) for x in col) for col in zip(head, *rows)]
sep = "+" + "+".join("-" * (n + 2) for n in w) + "+"
fmt = lambda r: "| " + " | ".join(c.ljust(n) for c, n in zip(r, w)) + " |"
print(sep); print(fmt(head)); print(sep)
for r in rows: print(fmt(r))
print(sep)
print(f"{len(rows)} resource(s)")
'
}

# Full attributes of each matching resource (sensitive values stay redacted).
show_resources() {
  local dir="$1" addr
  if ! terraform -chdir="$dir" state list >/dev/null 2>&1; then
    warn "no state yet"
    return 0
  fi
  state_addresses "$dir" | while read -r addr; do
    terraform -chdir="$dir" state show -no-color "$addr" | sed 's/^/    /'
    echo
  done
}

run_root() {
  local entry="$1" rel="${1%%|*}" realm="${1#*|}" dir
  dir="$REPO_ROOT/$rel"
  bold "$rel"
  if ! has_config "$dir"; then
    warn "skipped (no resources defined yet)"
    return 0
  fi

  case "$ACTION" in
    resources) list_resources "$dir"; return 0 ;;
    show)      show_resources "$dir"; return 0 ;;
    outputs)   terraform -chdir="$dir" output || warn "no outputs"; return 0 ;;
  esac

  local missing
  missing="$(missing_remote_state "$dir")"
  if [ -n "$missing" ]; then
    warn "skipped — reads remote state that doesn't exist yet (apply its dependency first):"
    echo "$missing" | sed "s#^$REPO_ROOT/#      #"
    return 0
  fi

  terraform -chdir="$dir" init -input=false -upgrade=false >/dev/null
  var_args_for "$dir" "$realm"

  case "$ACTION" in
    plan)    terraform -chdir="$dir" plan -input=false ${VAR_ARGS[@]+"${VAR_ARGS[@]}"} ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} ;;
    apply)   terraform -chdir="$dir" apply -input=false ${VAR_ARGS[@]+"${VAR_ARGS[@]}"} ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
             list_resources "$dir" ;;
    destroy) terraform -chdir="$dir" destroy -input=false ${VAR_ARGS[@]+"${VAR_ARGS[@]}"} ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} ;;
  esac
}

case "$ACTION" in
  table)
    print_table ;;
  plan|apply|resources|show|outputs)
    for entry in "${ROOTS[@]}"; do run_root "$entry"; done ;;
  destroy)
    for (( i=${#ROOTS[@]}-1; i>=0; i-- )); do run_root "${ROOTS[$i]}"; done ;;
  *)
    sed -n '2,/^set -euo/p' "$0" | sed '$d'; exit 1 ;;
esac

if [ "$ACTION" = "apply" ]; then
  bold "Summary"
  print_table
fi
