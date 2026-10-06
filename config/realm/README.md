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

## Email (SMTP)

Mail servers are listed once under `smtp_servers:` at the bottom of `realms.yml`, and a
realm picks one by name:

```yaml
realms:
  - realm: home-human-automation
    smtp: mailpit

smtp_servers:
  mailpit:
    host: mailpit
    port: 1025
    from: noreply@kraaj.studio
```

Terraform copies the chosen server into that realm's Email settings in Keycloak (Realm
settings → Email); Keycloak never reads the YAML itself. A realm without `smtp:` sends no
email, so "verify email" and "forgot password" fail there.

`mailpit` is the local fake mail server from `E:\MyIAM` (inbox: <http://localhost:8025>),
for development only. For a real server with a login, set `username` in `smtp_servers:` and
its password outside git, keyed by the server's name:

```hcl
# terraform.tfvars (gitignored)
smtp_passwords = {
  production = "..."
}
```

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
