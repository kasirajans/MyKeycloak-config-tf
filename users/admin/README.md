# Keycloak User Management with Terraform

This Terraform configuration manages user creation and import in Keycloak from a CSV file.

## Structure

- `main.tf` - Main Terraform configuration for user resources
- `variables.tf` - Variable definitions
- `outputs.tf` - Output definitions
- `terraform.tfvars` - Configuration values (DO NOT commit sensitive data)
- `users.csv` - User data to import
- `.gitignore` - Excludes sensitive files from git

## Prerequisites

1. Keycloak instance running and accessible
2. Admin credentials or a service account with user management permissions
3. Terraform installed (v1.0+)

## CSV Format

The `users.csv` file should contain the following columns:

- `username` (required) - Unique username
- `email` (required) - User email address
- `first_name` (optional) - First name
- `last_name` (optional) - Last name
- `enabled` (optional) - true/false, defaults to true
- `email_verified` (optional) - true/false, defaults to false
- `password` (optional) - Initial password, defaults to "ChangeMe123!"
- `temporary_password` (optional) - true/false, defaults to true
- `groups` (optional) - Comma-separated group names

## Setup

1. **Configure Keycloak credentials:**
   Edit `terraform.tfvars` with your Keycloak details:
   ```hcl
   keycloak_url           = "https://your-keycloak-instance.com"
   keycloak_realm         = "your-realm"
   keycloak_client_id     = "admin-cli"
   keycloak_client_secret = "your-secret"
   ```

2. **Prepare users CSV:**
   Edit `users.csv` with the users you want to import.

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Review the plan:**
   ```bash
   terraform plan
   ```

5. **Apply the configuration:**
   ```bash
   terraform apply
   ```

## Security Notes

- **NEVER** commit `terraform.tfvars` or `users.csv` to version control
- The `.gitignore` file is configured to exclude sensitive files
- Consider using environment variables or a secrets manager for credentials
- Use temporary passwords that force users to change on first login

## Group Assignments

To assign users to groups, you need to:

1. Get the group IDs from Keycloak
2. Add them to the `group_mappings` variable in `terraform.tfvars`
3. Reference group names in the `groups` column of `users.csv`

Example:
```hcl
group_mappings = {
  "admins"     = "f47ac10b-58cc-4372-a567-0e02b2c3d479"
  "developers" = "550e8400-e29b-41d4-a716-446655440000"
}
```

## Cleanup

To remove all created users:
```bash
terraform destroy
```
