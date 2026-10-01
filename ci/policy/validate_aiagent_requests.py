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
