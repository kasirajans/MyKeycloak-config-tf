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

## Viewing Created Users

### Get All User Information

```bash
# View all users with full details (excluding passwords)
terraform output -json user_credentials_summary | jq

# View specific user details
terraform output -json user_credentials_summary | jq '.["user1@consumer.com"]'
```

### Get User Passwords

Passwords are sensitive and hidden by default. Use these commands to retrieve them:

```bash
# View all user passwords
terraform output -json user_passwords | jq

# View all user passwords in plain text (remove quotes)
terraform output -json user_passwords | jq -r

# Get specific user's password
terraform output -json user_passwords | jq -r '.["user1@consumer.com"]'
```

### Get User Emails and Passwords Together

```bash
# List all users with their emails and passwords in table format
echo "EMAIL | PASSWORD"
echo "------|----------"
for email in $(terraform output -json user_passwords | jq -r 'keys[]'); do
  password=$(terraform output -json user_passwords | jq -r ".\"$email\"")
  echo "$email | $password"
done

# Export to CSV file
echo "email,password" > user_credentials.csv
for email in $(terraform output -json user_passwords | jq -r 'keys[]'); do
  password=$(terraform output -json user_passwords | jq -r ".\"$email\"")
  echo "$email,$password" >> user_credentials.csv
done
echo "Credentials exported to user_credentials.csv"
```

### Get Complete User Information with Passwords

```bash
# Get all user details including passwords
for email in $(terraform output -json user_credentials_summary | jq -r 'keys[]'); do
  echo "==================================="
  echo "Email: $email"
  echo "User ID: $(terraform output -json user_credentials_summary | jq -r ".\"$email\".user_id")"
  echo "First Name: $(terraform output -json user_credentials_summary | jq -r ".\"$email\".first_name")"
  echo "Last Name: $(terraform output -json user_credentials_summary | jq -r ".\"$email\".last_name")"
  echo "Enabled: $(terraform output -json user_credentials_summary | jq -r ".\"$email\".enabled")"
  echo "Password: $(terraform output -json user_passwords | jq -r ".\"$email\"")"
  echo ""
done

# Export complete user information to JSON
jq -n \
  --argjson summary "$(terraform output -json user_credentials_summary)" \
  --argjson passwords "$(terraform output -json user_passwords)" \
  '$summary | to_entries | map({
    email: .key,
    user_id: .value.user_id,
    first_name: .value.first_name,
    last_name: .value.last_name,
    enabled: .value.enabled,
    password: $passwords[.key]
  })' > complete_user_info.json
echo "Complete user information exported to complete_user_info.json"
```

### Quick Reference Commands

```bash
# Count total users created
terraform output user_count

# List all user emails
terraform output -json user_credentials_summary | jq -r 'keys[]'

# List users assigned to groups
terraform output users_with_groups

# Get realm information
terraform output realm_name
terraform output realm_id

# Simple list: Email and Password only
terraform output -json user_passwords | jq -r 'to_entries[] | "\(.key): \(.value)"'
```

### Create a Helper Script

Save this as `get-user-credentials.sh`:

```bash
#!/bin/bash

echo "========================================"
echo "Keycloak User Credentials"
echo "========================================"
echo ""

for email in $(terraform output -json user_credentials_summary | jq -r 'keys[]'); do
  first_name=$(terraform output -json user_credentials_summary | jq -r ".\"$email\".first_name")
  last_name=$(terraform output -json user_credentials_summary | jq -r ".\"$email\".last_name")
  password=$(terraform output -json user_passwords | jq -r ".\"$email\"")
  enabled=$(terraform output -json user_credentials_summary | jq -r ".\"$email\".enabled")
  
  echo "Name: $first_name $last_name"
  echo "Email: $email"
  echo "Password: $password"
  echo "Status: $([ "$enabled" = "true" ] && echo "Enabled" || echo "Disabled")"
  echo "----------------------------------------"
  echo ""
done

echo "Total Users: $(terraform output user_count)"
```

Make it executable:
```bash
chmod +x get-user-credentials.sh
./get-user-credentials.sh
```

## Security Notes

- **NEVER** commit `terraform.tfvars` or `users.csv` to version control
- **NEVER** commit generated credential files (`user_credentials.csv`, `complete_user_info.json`)
- The `.gitignore` file is configured to exclude sensitive files
- Consider using environment variables or a secrets manager for credentials
- Use temporary passwords that force users to change on first login
- **Password Security:**
  - Generated passwords are 16 characters with complexity requirements
  - Passwords are stored in Terraform state file (keep state secure!)
  - Only share passwords through secure channels
  - Delete exported credential files after distribution
  - Consider using a password manager to securely share credentials

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
