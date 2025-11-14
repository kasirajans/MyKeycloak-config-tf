# Unified Realm Configuration

This directory contains a unified Terraform configuration for managing multiple Keycloak realms from a single YAML file.

## Overview

Instead of maintaining separate directories for each realm (idp-customer, sp-customer), all realm configurations are now defined in a single `realms.yml` file and managed by a common set of Terraform files.

## Files

- **`realms.yml`**: YAML configuration file containing all realm definitions
- **`main.tf`**: Main Terraform configuration that reads from `realms.yml` and creates all realms
- **`variables.tf`**: Input variables for Keycloak connection
- **`outputs.tf`**: Outputs for all created realms
- **`terraform.tfvars`**: Variable values (Keycloak URL, credentials)

## Structure

### realms.yml

The `realms.yml` file contains an array of realm configurations. Each realm can specify:

- Basic settings (name, display name, enabled status)
- Login settings (email login, registration, password reset, etc.)
- Session timeouts (SSO, offline sessions, token lifespan)
- Security settings (SSL requirements, password policies)
- Internationalization (supported locales)
- Security defenses (headers, brute force protection)
- Browser flows

### Adding a New Realm

To add a new realm, simply add a new entry to the `realms` array in `realms.yml`:

```yaml
realms:
  - name: "new-realm"
    display_name: "New Realm"
    display_name_html: "<b>New Realm</b>"
    enabled: true
    # ... (copy settings from existing realm and modify as needed)
```

### Modifying Existing Realms

To modify a realm, edit its configuration in `realms.yml`. Changes will be applied on the next `terraform apply`.

## Usage

### Initialize Terraform

```bash
cd /d/homelab/MyKeycloak-config-tf/config/realm
terraform init
```

### Plan Changes

```bash
terraform plan
```

### Apply Changes

```bash
terraform apply
```

### View Outputs

```bash
# View all realm details
terraform output realms

# View specific realm
terraform output idp_customer_realm
terraform output sp_customer_realm

# View endpoints for all realms
terraform output realm_endpoints
```

## Configuration

### Keycloak Connection

Edit `terraform.tfvars` to configure the Keycloak connection:

```hcl
keycloak_url      = "http://localhost:8080"
keycloak_username = "admin"
keycloak_password = "admin"
```

### SMTP Configuration (Optional)

To enable SMTP for all realms, uncomment and configure the `smtp_server` section in `realms.yml`:

```yaml
smtp_server:
  enabled: true
  host: "smtp.example.com"
  port: "587"
  from: "noreply@example.com"
  from_display_name: "Keycloak"
  ssl: false
  starttls: true
  username: "smtp-user"
  password: "smtp-password"
```

## Current Realms

The configuration currently manages the following realms:

1. **idp-customer** - Identity Provider Customer
2. **sp-customer** - Service Provider Customer

Both realms are configured with:
- Email-based login
- Password reset enabled
- 30-minute SSO session idle timeout
- 10-hour SSO session max lifespan
- Strong password policy
- Brute force protection
- Security headers

## Migration from Separate Directories

The previous structure had separate directories:
- `idp-customer/` - Now consolidated into `realms.yml`
- `sp-customer/` - Now consolidated into `realms.yml`

These directories are no longer needed and can be archived or removed after confirming the unified configuration works correctly.

## Benefits

✅ **Single source of truth**: All realm configurations in one file  
✅ **Easy comparison**: See differences between realms at a glance  
✅ **Simplified management**: One `terraform apply` for all realms  
✅ **Consistent configuration**: Share common settings across realms  
✅ **Easy to scale**: Add new realms without creating new directories  

## Testing

After applying the configuration, verify the realms are created correctly:

```bash
# Check Keycloak admin console
# http://localhost:8080/admin

# Or query via terraform output
terraform output realms
```

## Cleanup Old State (If Needed)

If you need to migrate from the old separate configurations to this unified one:

1. Backup existing state files from `idp-customer/` and `sp-customer/`
2. Import existing realms into the new configuration:

```bash
terraform import 'keycloak_realm.realms["idp-customer"]' idp-customer
terraform import 'keycloak_realm.realms["sp-customer"]' sp-customer
```

3. Run `terraform plan` to verify no changes are needed
4. If everything looks good, archive the old directories

## Troubleshooting

### YAML Syntax Error

If you see YAML parsing errors, validate your `realms.yml`:
```bash
# Using Python
python -c "import yaml; yaml.safe_load(open('realms.yml'))"

# Using yq (if installed)
yq eval '.' realms.yml
```

### Realm Already Exists

If a realm already exists in Keycloak, import it:
```bash
terraform import 'keycloak_realm.realms["realm-name"]' realm-name
```

### Changes Not Applied

Ensure you're in the correct directory and have run `terraform init`:
```bash
pwd  # Should show: /d/homelab/MyKeycloak-config-tf/config/realm
terraform init
terraform apply
```
