# Migration Guide: Unified Realm Configuration

This guide explains how to migrate from the separate `idp-customer` and `sp-customer` directories to the unified `realms.yml` configuration.

## What Changed

### Before (Separate Directories)
```
config/realm/
├── idp-customer/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
├── sp-customer/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
```

### After (Unified Configuration)
```
config/realm/
├── realms.yml          # Single YAML file with all realm configs
├── main.tf             # Common main.tf that reads from realms.yml
├── variables.tf        # Simplified variables
├── outputs.tf          # Outputs for all realms
├── terraform.tfvars    # Single tfvars file
└── README.md           # Documentation
```

## Migration Steps

### Step 1: Verify Current State

First, check if you have existing realms deployed:

```bash
# Check idp-customer realm
cd /d/homelab/MyKeycloak-config-tf/config/realm/idp-customer
terraform show

# Check sp-customer realm
cd /d/homelab/MyKeycloak-config-tf/config/realm/sp-customer
terraform show
```

### Step 2: Export Existing Realms (If They Exist)

If the realms already exist in Keycloak, you'll need to import them into the new configuration:

```bash
cd /d/homelab/MyKeycloak-config-tf/config/realm

# Import idp-customer realm
terraform import 'keycloak_realm.realms["idp-customer"]' idp-customer

# Import sp-customer realm
terraform import 'keycloak_realm.realms["sp-customer"]' sp-customer
```

### Step 3: Verify the New Configuration

```bash
cd /d/homelab/MyKeycloak-config-tf/config/realm

# Validate configuration
terraform validate

# Check what changes would be made
terraform plan
```

**Expected Result**: If the realms already exist and are imported correctly, `terraform plan` should show **no changes** or only minor formatting differences.

### Step 4: Apply the Configuration

If the plan looks good (no unwanted changes):

```bash
terraform apply
```

Type `yes` when prompted.

### Step 5: Archive Old Directories

Once you've verified everything works:

```bash
cd /d/homelab/MyKeycloak-config-tf/config/realm

# Create archive directory
mkdir -p _archived

# Move old directories
mv idp-customer _archived/
mv sp-customer _archived/

# Or delete them if you're confident
# rm -rf idp-customer sp-customer
```

## Verification Checklist

After migration, verify:

- [ ] Both realms are visible in Keycloak Admin Console
- [ ] Login to both realms works correctly
- [ ] Client applications can still authenticate
- [ ] Users can still log in
- [ ] `terraform output realms` shows both realms
- [ ] `terraform plan` shows no unexpected changes

## Testing the New Configuration

```bash
# View all realms
terraform output realms

# View specific realm details
terraform output idp_customer_realm
terraform output sp_customer_realm

# View realm endpoints
terraform output realm_endpoints

# View session settings
terraform output session_settings
```

## If Things Go Wrong

### Realms Don't Exist Yet

If you haven't deployed the realms yet, simply:

```bash
cd /d/homelab/MyKeycloak-config-tf/config/realm
terraform init
terraform apply
```

### Import Failed

If import fails, check:
1. Keycloak is running: `curl http://localhost:8080/health/ready`
2. Credentials are correct in `terraform.tfvars`
3. Realm names match exactly

### Unexpected Changes in Plan

If `terraform plan` shows unexpected changes after import:

1. Review the changes carefully
2. Update `realms.yml` to match the existing realm configuration
3. Run `terraform plan` again
4. Repeat until no changes are shown

### Need to Rollback

If you need to go back to the old structure:

```bash
# Restore old directories from archive
mv _archived/idp-customer ./
mv _archived/sp-customer ./

# Or restore from git
git checkout -- idp-customer/ sp-customer/
```

## Adding New Realms

To add a new realm after migration:

1. Edit `realms.yml` and add a new realm entry
2. Run `terraform plan` to preview
3. Run `terraform apply` to create

Example:

```yaml
realms:
  - name: "idp-customer"
    # ... existing config ...
    
  - name: "sp-customer"
    # ... existing config ...
    
  - name: "new-realm"
    display_name: "New Realm"
    display_name_html: "<b>New Realm</b>"
    enabled: true
    # ... copy settings from existing realm and modify ...
```

## Benefits of Migration

✅ **Simplified Management**: One file to manage all realms  
✅ **Easy Comparison**: See differences between realms at a glance  
✅ **Version Control**: Better diff visualization in Git  
✅ **Scalability**: Add new realms without creating directories  
✅ **Consistency**: Ensure all realms follow the same structure  
✅ **Single Apply**: Update all realms with one command  

## Support

If you encounter issues:

1. Check `README.md` in the realm directory
2. Review Terraform error messages carefully
3. Verify Keycloak is accessible
4. Check terraform state: `terraform show`

## Summary

The unified configuration provides the same functionality as the separate directories but with better maintainability. All realm settings are now in one place (`realms.yml`), making it easier to:

- Compare realm configurations
- Add new realms
- Maintain consistency
- Track changes in version control

The migration preserves all existing realm configurations and functionality.
