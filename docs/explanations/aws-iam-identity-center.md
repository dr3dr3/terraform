# AWS IAM Identify Center

## What IAM Identity Center Does

Instead of creating separate IAM users in each account, you create one identity in IAM Identity Center that can access all your AWS accounts. You'll get a custom sign-in URL (like `https://d-xxxxxxxxxx.awsapps.com/start`) where you log in once and see all your accounts.

## Setup Steps

### 1. Enable AWS Organizations (if you haven't already)

- Go to AWS Organizations in your management account
- Click "Create organization"
- Invite or create your dev, staging, and prod accounts under it

### 2. Enable IAM Identity Center

- In the management account, go to IAM Identity Center
- Click "Enable"
- Choose your identity source - for just yourself, use the default "Identity Center directory" (built-in)
- AWS will assign you a sign-in URL

### 3. Create Your User

- In IAM Identity Center, go to Users
- Click "Add user"
- Enter your email, first/last name
- You'll receive an email to set your password
- Enable MFA for this user (highly recommended)

### 4. Create Permission Sets

- These are like IAM roles that define what you can do
- Go to "Permission sets" and create a few:
  - `AdministratorAccess` - full admin (for learning/dev work)
  - `ReadOnlyAccess` - view-only (if you want to practice least privilege)
- You can use AWS managed policies or create custom ones

### 5. Assign Access

- Go to "AWS accounts" in IAM Identity Center
- Select an account (e.g., dev)
- Click "Assign users or groups"
- Select your user
- Select the permission set (e.g., AdministratorAccess)
- Repeat for staging and prod accounts

## How You'll Use It Daily

1. Go to your IAM Identity Center sign-in URL (bookmark it!)
2. Log in with your email and password
3. You'll see tiles for all your accounts
4. Click on an account to get temporary credentials
5. Choose "Management console" to open the AWS Console, or "Command line or programmatic access" to get credentials for CLI/Terraform

## For Terraform/CLI Access

When you click "Command line or programmatic access" for an account, you'll see options:

**Option 1: Manual credentials** (copy/paste environment variables)

**Option 2: AWS CLI v2** (recommended)

```bash
# Configure your profile
aws configure sso
# SSO session name: my-sso
# SSO start URL: https://d-xxxxxxxxxx.awsapps.com/start
# SSO region: us-east-1
# SSO registration scopes: sso:account:access

# Then authenticate
aws sso login --profile dev

# Use with Terraform
export AWS_PROFILE=dev
terraform plan
```

## Key Benefits for You

- One password instead of three
- Temporary credentials that auto-rotate
- Easy to switch between accounts
- More secure than long-term IAM access keys
- No IAM users to manage

The whole setup takes about 10-15 minutes. Once done, you'll never touch IAM users again - everything goes through Identity Center
