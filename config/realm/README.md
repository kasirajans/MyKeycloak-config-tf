# config/realm

One consolidated root module managing all 3 realms (`customer`, `home-human-automation`,
`ai-agent`) in a single Terraform state. All three realms' settings live as a list in
one `realms.yml`; `main.tf` here reads it via `for_each` and calls `modules/realm` once
per entry — that module owns 100% of the actual resource logic. Adding a 4th realm later
is just another list entry in `realms.yml`, no new file/directory needed.

Realms are low-churn (create once, rarely touched again), so one shared state for all
three was chosen over isolating each into its own root module — see the top-level
README's "State boundaries" section for the general per-directory-state principle this
is a deliberate exception to.

## Prerequisites

- Terraform >= 1.5
- A running Keycloak instance reachable from where you run Terraform
- Keycloak admin credentials (admin username/password grant, via `admin-cli`)

## Run it

Either export env vars:

```
export KEYCLOAK_URL="http://localhost:8080"
export KEYCLOAK_USER="admin"
export KEYCLOAK_PASSWORD="<your-admin-password>"
```

...or copy `terraform.tfvars.example` to `terraform.tfvars` (gitignored) and fill in real
values — Terraform auto-loads `terraform.tfvars`, no flag needed. Either path works; the
provider falls back to the env vars if the corresponding tfvars value is unset.

```
cd config/realm
terraform init
terraform plan
terraform apply
```

State is local (`terraform.tfstate` in this directory, gitignored) until a remote
backend is configured — fine for a first run, not for team use.
