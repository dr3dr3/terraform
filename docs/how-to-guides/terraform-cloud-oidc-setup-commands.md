# Setup Commands: Terraform Cloud OIDC Authentication

Quick reference with exact AWS CLI commands to set up OIDC authentication.

## Prerequisites

```bash
# Set your AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"

# Verify AWS CLI access
aws sts get-caller-identity
```

## Step 1: Create OIDC Provider

```bash
# Create the OIDC provider for Terraform Cloud
aws iam create-open-id-connect-provider \
  --url "https://app.terraform.io" \
  --client-id-list "aws.workload.identity" \
  --thumbprint-list "9e99a48a9960b14926bb7f3b02e22da2b0ab7280" \
  --tags Key=Name,Value=terraform-cloud-oidc-provider \
         Key=Purpose,Value="Terraform Cloud OIDC authentication"

# Verify it was created
aws iam list-open-id-connect-providers
```

## Step 2: Create Trust Policy

Save this as `trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID_PLACEHOLDER:oidc-provider/app.terraform.io"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "app.terraform.io:aud": "aws.workload.identity"
        },
        "StringLike": {
          "app.terraform.io:sub": "organization:Datafaced:project:*:workspace:*:run_phase:*"
        }
      }
    }
  ]
}
```

Replace `ACCOUNT_ID_PLACEHOLDER`:

```bash
# Prepare the trust policy with your actual account ID
sed -i "s/ACCOUNT_ID_PLACEHOLDER/$AWS_ACCOUNT_ID/g" trust-policy.json

# Verify it looks correct
cat trust-policy.json
```

## Step 3: Create IAM Role

```bash
# Create the role with the trust policy
aws iam create-role \
  --role-name terraform-cloud-oidc-role \
  --assume-role-policy-document file://trust-policy.json \
  --tags Key=Name,Value=terraform-cloud-oidc-role \
         Key=Purpose,Value="Terraform Cloud OIDC role" \
         Key=ManagedBy,Value=terraform

# Get the role ARN
ROLE_ARN=$(aws iam get-role --role-name terraform-cloud-oidc-role --query 'Role.Arn' --output text)
echo "Role ARN: $ROLE_ARN"
```

## Step 4: Create and Attach Inline Policy

Save this as `inline-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ManageIAMIdentityCenter",
      "Effect": "Allow",
      "Action": [
        "identitystore:*",
        "sso:*",
        "ssoadmin:*"
      ],
      "Resource": "*"
    }
  ]
}
```

Attach the policy:

```bash
aws iam put-role-policy \
  --role-name terraform-cloud-oidc-role \
  --policy-name terraform-cloud-policy \
  --policy-document file://inline-policy.json

# Verify it was attached
aws iam get-role-policy \
  --role-name terraform-cloud-oidc-role \
  --policy-name terraform-cloud-policy
```

## Step 5: Verify OIDC Setup

```bash
# List OIDC providers
aws iam list-open-id-connect-providers

# Describe the OIDC provider
OIDC_ARN=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[0].Arn' --output text)
aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN"

# Verify role exists
aws iam get-role --role-name terraform-cloud-oidc-role

# Get role ARN for Terraform Cloud configuration
aws iam get-role --role-name terraform-cloud-oidc-role --query 'Role.Arn' --output text
```

## Step 6: Configure Terraform Cloud

In Terraform Cloud web interface:

```bash
# After creating variable set, configure these environment variables:

# Variable 1: Enable AWS provider auth
TFC_AWS_PROVIDER_AUTH = "true"

# Variable 2: Role ARN (use the output from step 5)
TFC_AWS_ROLE_ARN = "<role-arn-from-step-5>"

# Variable 3: Session name
TFC_AWS_ROLE_SESSION_NAME = "terraform-cloud-session"
```

Or use Terraform to configure it:

```bash
# Set your Terraform Cloud token
export TFE_TOKEN="your-terraform-cloud-api-token"

# Export organization name
export TFC_ORG="Datafaced"
export TFC_WORKSPACE="management-foundation-iam-roles-for-people"
export TFC_ROLE_ARN="$ROLE_ARN"
```

## Step 7: Test the Setup

```bash
# Push a test commit to your repository
cd /workspace/terraform/env-management/foundation-layer/iam-roles-for-people

# Make a small comment change
echo "# Test OIDC configuration" >> main.tf

# Commit and push
git add main.tf
git commit -m "test: terraform cloud oidc auth"
git push origin main

# Watch the run in Terraform Cloud console
# https://app.terraform.io/app/Datafaced/workspaces/management-foundation-iam-roles-for-people/runs
```

## Step 8: Verify in CloudTrail

```bash
# Check for AssumeRoleWithWebIdentity events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity \
  --max-items 10 \
  --region ap-southeast-2 \
  --query 'Events[*].[EventTime,Username,EventName]' \
  --output table

# You should see entries like:
# 2025-11-26T10:30:00Z | app.terraform.io | AssumeRoleWithWebIdentity
```

## Troubleshooting Commands

```bash
# Check if OIDC provider exists
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/app.terraform.io"

# Verify role trust policy
aws iam get-role --role-name terraform-cloud-oidc-role \
  --query 'Role.AssumeRolePolicyDocument' | jq .

# List role policies
aws iam list-role-policies --role-name terraform-cloud-oidc-role

# Get the actual policy
aws iam get-role-policy \
  --role-name terraform-cloud-oidc-role \
  --policy-name terraform-cloud-policy \
  --query 'RolePolicyDocument' | jq .

# Check CloudTrail for errors
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity \
  --max-items 5 \
  --region ap-southeast-2 \
  --query 'Events[*].[EventTime,Username,CloudTrailEvent]' \
  | jq '.[] | select(.[] | contains("error"))'
```

## Cleanup (If Needed)

```bash
# Delete the inline policy
aws iam delete-role-policy \
  --role-name terraform-cloud-oidc-role \
  --policy-name terraform-cloud-policy

# Delete the role
aws iam delete-role --role-name terraform-cloud-oidc-role

# Delete the OIDC provider
aws iam delete-open-id-connect-provider \
  --open-id-connect-provider-arn "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/app.terraform.io"
```

## Using Terraform Instead (Recommended for IaC)

Instead of AWS CLI, you can use Terraform to manage OIDC:

```hcl
# See the sample configuration in:
# /workspace/terraform/env-management/foundation-layer/terraform-cloud-oidc-role/main.tf
```

## Full Setup Summary

```bash
# Quick reference: all commands in order
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 1. Create OIDC provider
aws iam create-open-id-connect-provider \
  --url "https://app.terraform.io" \
  --client-id-list "aws.workload.identity" \
  --thumbprint-list "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"

# 2. Create trust policy file and role (see steps 2-3 above)
# 3. Create and attach policy (see steps 4 above)
# 4. Get role ARN
aws iam get-role --role-name terraform-cloud-oidc-role \
  --query 'Role.Arn' --output text

# 5. Configure Terraform Cloud with role ARN (manual UI step)
# 6. Test with push
# 7. Verify in CloudTrail
```

## References

- [AWS IAM OIDC](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html)
- [Terraform Cloud OIDC](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials)
