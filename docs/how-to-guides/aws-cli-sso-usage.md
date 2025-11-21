# Setting up AWS CLI with IAM Identity Center (SSO)

## Prerequisites

Make sure you have AWS CLI v2 installed (SSO support requires v2):

```bash
# Check your version
aws --version

# Should show something like: aws-cli/2.x.x
```

If you need to install or upgrade: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

## Setup Process

**1. Configure SSO Profile**

Run the configure command for your first account (let's start with dev):

```bash
aws configure sso
```

You'll be prompted for:

```
SSO session name (Recommended): my-aws-sso
SSO start URL [None]: https://d-xxxxxxxxxx.awsapps.com/start
SSO region [None]: us-east-1
SSO registration scopes [sso:account:access]:
```

**Key points:**
- **SSO session name**: Pick something memorable (e.g., `my-aws-sso` or `personal-aws`)
- **SSO start URL**: Your IAM Identity Center URL (found in the IAM Identity Center console)
- **SSO region**: Region where you enabled IAM Identity Center (usually `us-east-1`)
- **Registration scopes**: Just press Enter to accept default

**2. Authenticate in Browser**

The CLI will open your browser to authenticate. Log in with your IAM Identity Center credentials.

**3. Select Account and Role**

After authentication, the CLI will show your available accounts:

```
There are 3 AWS accounts available to you.
> 123456789012 (dev-account)
  234567890123 (staging-account)
  345678901234 (prod-account)
```

Select your dev account, then choose the permission set (role):

```
Using the account ID 123456789012
There are 2 roles available to you.
> AdministratorAccess
  ReadOnlyAccess
```

**4. Name Your Profile**

```
CLI default client Region [None]: us-east-1
CLI default output format [None]: json
CLI profile name [AdministratorAccess-123456789012]: dev
```

Use simple, memorable names like `dev`, `staging`, `prod`.

## Repeat for Other Accounts

Now configure your staging and prod accounts:

```bash
# Staging
aws configure sso

# Use the SAME SSO session name: my-aws-sso
# Use the SAME SSO start URL
# Select staging account
# Name profile: staging

# Production
aws configure sso

# Use the SAME SSO session name: my-aws-sso
# Use the SAME SSO start URL
# Select prod account
# Name profile: prod
```

**Important:** Use the same SSO session name for all profiles. This way you authenticate once and access all accounts.

## Your Config Files

After setup, check your config file:

```bash
cat ~/.aws/config
```

It should look like:

```ini
[profile dev]
sso_session = my-aws-sso
sso_account_id = 123456789012
sso_role_name = AdministratorAccess
region = us-east-1
output = json

[profile staging]
sso_session = my-aws-sso
sso_account_id = 234567890123
sso_role_name = AdministratorAccess
region = us-east-1
output = json

[profile prod]
sso_session = my-aws-sso
sso_account_id = 345678901234
sso_role_name = AdministratorAccess
region = us-east-1
output = json

[sso-session my-aws-sso]
sso_start_url = https://d-xxxxxxxxxx.awsapps.com/start
sso_region = us-east-1
sso_registration_scopes = sso:account:access
```

## Daily Usage

**List profile setup:**
```bash
aws configure list-profiles
```

**Authenticate once:**
```bash
aws sso login --sso-session my-aws-sso
```

This logs you in to ALL accounts at once.

**Use specific profiles:**
```bash
# List S3 buckets in dev
aws s3 ls --profile dev

# List EC2 instances in prod
aws ec2 describe-instances --profile prod

# Export profile for multiple commands
export AWS_PROFILE=dev
aws s3 ls
aws ec2 describe-instances
```

**Check current credentials:**
```bash
aws sts get-caller-identity --profile dev
```

## For Terraform

Set the profile before running Terraform:

```bash
export AWS_PROFILE=dev
terraform init
terraform plan
```

Or configure it in your Terraform provider:

```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "dev"
}
```

## Session Management

**Sessions expire** after a period (typically 8-12 hours). When they expire:

```bash
# Just re-authenticate
aws sso login --sso-session my-aws-sso
```

**Check if session is valid:**
```bash
aws sts get-caller-identity --profile dev
```

If you get an error, your session expired - just run the login command again.

## Troubleshooting

**"Error loading SSO Token"**
```bash
aws sso login --sso-session my-aws-sso
```

**Want to reconfigure a profile?**
```bash
# Edit directly
nano ~/.aws/config

# Or reconfigure
aws configure sso --profile dev
```

**Clear cached credentials:**
```bash
rm -rf ~/.aws/sso/cache/
rm -rf ~/.aws/cli/cache/
```

That's it! You're now set up with SSO. Much cleaner than managing access keys, and your credentials rotate automatically. Let me know if you hit any snags!