# config/smtp

The mail servers Keycloak sends email through (verify email, forgot password, ...), listed
once in `smtp.yml` and chosen per realm.

This folder has **no Terraform of its own and no state**. Keycloak stores a realm's mail
settings on the realm itself, so `config/realm/` applies them: it reads `smtp.yml` and
gives each realm the server named by its `smtp:` key in `realms.yml`. A separate state
would fight `config/realm/` over the same realm.

## Use a server in a realm

`config/realm/realms.yml`:

```yaml
  - realm: home-human-automation
    smtp: mailpit
```

Then apply `config/realm/`. A realm with no `smtp:` sends no email, so "verify email" and
"forgot password" fail there.

## Add a server

Add an entry under `servers:` in `smtp.yml`. If it needs a login, set `username` there and
the password outside git, keyed by the server's name:

```hcl
# config/realm/terraform.tfvars (gitignored)
smtp_passwords = {
  production = "..."
}
```

or in a pipeline: `TF_VAR_smtp_passwords='{"production":"..."}'`.

## Servers today

| Name | What | Used by |
|---|---|---|
| `mailpit` | Local fake mail server (`E:\MyIAM`, see its `SMTP/README.md`). Inbox: <http://localhost:8025>. Development only. | `customer`, `home-human-automation` |

`ai-agent` has none: it has no browser logins, so it never sends email.
