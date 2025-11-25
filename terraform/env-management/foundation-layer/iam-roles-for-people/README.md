# IAM Roles for People - IAM Identity Center Configuration

This Terraform configuration creates IAM Identity Center (AWS SSO) groups and permission sets for human users accessing AWS accounts.

## Overview

This module provisions three user groups with different permission levels:

1. **Administrators** - Full administrative access to all AWS resources
2. **Platform Engineers** - Permissions focused on creating and managing EKS clusters and related infrastructure
3. **ReadOnly** - Read-only access to all AWS resources

## Architecture

### Groups

- `Administrators`: Full admin access using AWS managed `AdministratorAccess` policy
- `Platform-Engineers`: Custom permissions for EKS cluster management and platform infrastructure
- `ReadOnly`: Read-only access using AWS managed `ReadOnlyAccess` policy

### Permission Sets

Each group has a corresponding permission set that defines what actions users in that group can perform:

#### Administrator Access

- AWS Managed Policy: `AdministratorAccess`
- Session Duration: 8 hours
- Use Case: Full administrative operations

#### Platform Engineer Access

- Custom inline policy with permissions for:
  - EKS cluster creation, deletion, and management
  - EKS node group management
  - EKS add-ons and Fargate profiles
  - IAM roles and policies for EKS (with restricted naming)
  - OIDC provider management for EKS IRSA
  - VPC and networking resources for EKS
  - Auto Scaling groups for node groups
  - Load balancers and target groups
  - CloudWatch logs for EKS
  - KMS keys for EKS encryption
  - EC2 instances and launch templates
- Session Duration: 8 hours
- Use Case: Creating and managing Kubernetes clusters and platform infrastructure

#### ReadOnly Access

- AWS Managed Policy: `ReadOnlyAccess`
- Session Duration: 12 hours
- Use Case: Auditing, monitoring, and troubleshooting without modification rights

## Prerequisites

1. **AWS Organizations** must be enabled in your management account
2. **IAM Identity Center** must be enabled
3. You must run this Terraform in the **management account** where IAM Identity Center is configured
4. Appropriate AWS credentials with permissions to manage IAM Identity Center resources

## Usage

### 1. Configure Backend

Edit `backend.tf` to configure your Terraform backend (Terraform Cloud or S3).

### 2. Create terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
owner       = "your-email@example.com"
cost_center = "engineering"

# Optional: Assign permission sets to additional accounts
additional_account_ids = [
  "111111111111",  # Dev account
  "222222222222",  # Staging account
  "333333333333",  # Production account
]
```

### 3. Initialize and Apply

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

## Adding Users to Groups

After Terraform creates the groups, you need to add users to them:

### Option 1: AWS Console

1. Go to IAM Identity Center in the AWS Console
2. Navigate to "Groups"
3. Select a group (e.g., "Platform-Engineers")
4. Click "Add users"
5. Select users and click "Add users"

### Option 2: AWS CLI

```bash
# List available groups
aws identitystore list-groups \
  --identity-store-id $(terraform output -raw identity_store_id)

# Add a user to a group
aws identitystore create-group-membership \
  --identity-store-id $(terraform output -raw identity_store_id) \
  --group-id $(terraform output -raw platform_engineers_group_id) \
  --member-id UserId=<user-id>
```

### Option 3: Terraform (Future Enhancement)

You can extend this configuration to manage group memberships in Terraform using the `aws_identitystore_group_membership` resource.

## Accessing AWS Accounts

Once users are added to groups and permission sets are assigned:

1. Users receive an email with their IAM Identity Center sign-in URL (e.g., `https://d-xxxxxxxxxx.awsapps.com/start`)
2. Users log in with their credentials
3. Users see tiles for all accounts they have access to
4. Clicking an account shows available permission sets
5. Users can access the AWS Console or get CLI credentials

### AWS CLI Access

```bash
# Configure SSO profile
aws configure sso
# SSO session name: my-sso
# SSO start URL: https://d-xxxxxxxxxx.awsapps.com/start
# SSO region: us-east-1

# Login
aws sso login --profile <profile-name>

# Use with Terraform
export AWS_PROFILE=<profile-name>
terraform plan
```

## Permission Set Details

### Platform Engineer Permissions

The Platform Engineer permission set includes comprehensive EKS-related permissions:

- **EKS Operations**: Full cluster, node group, add-on, and Fargate profile management
- **IAM**: Create and manage roles/policies with `eks-*` naming prefix
- **OIDC**: Manage OIDC providers for EKS IRSA (IAM Roles for Service Accounts)
- **Networking**: Create and manage VPCs, subnets, security groups, NAT gateways
- **Compute**: Manage EC2 instances, launch templates, and Auto Scaling groups
- **Load Balancing**: Create and manage ALB/NLB for EKS ingress
- **Observability**: CloudWatch logs for EKS control plane and node groups
- **Security**: KMS key management for EKS encryption
- **Parameters**: Read SSM parameters for EKS AMIs and configurations

### Security Considerations

1. **Least Privilege**: Platform Engineers have focused permissions, not full admin
2. **Resource Restrictions**: Many permissions are scoped to `eks-*` named resources
3. **PassRole Protection**: IAM PassRole is restricted to EKS services only
4. **Session Duration**: Shorter sessions for admin (8h) vs readonly (12h)
5. **MFA Recommendation**: Enable MFA for all users, especially administrators

## Outputs

After applying, the following outputs are available:

```bash
terraform output sso_instance_arn              # IAM Identity Center instance ARN
terraform output identity_store_id             # Identity Store ID
terraform output admin_group_id                # Administrators group ID
terraform output platform_engineers_group_id   # Platform Engineers group ID
terraform output readonly_group_id             # ReadOnly group ID
terraform output admin_permission_set_arn      # Admin permission set ARN
terraform output platform_engineers_permission_set_arn  # Platform permission set ARN
terraform output readonly_permission_set_arn   # ReadOnly permission set ARN
```

## Assigning to Additional Accounts

To grant access to other accounts in your organization:

1. Add account IDs to `additional_account_ids` variable
2. Run `terraform apply`
3. Permission sets will be assigned to those accounts automatically

Alternatively, assign manually in the AWS Console:

1. IAM Identity Center → AWS accounts
2. Select an account
3. Click "Assign users or groups"
4. Select a group and permission set
5. Click "Submit"

## Customization

### Modifying Platform Engineer Permissions

Edit `policies.tf` to adjust the `data.aws_iam_policy_document.platform_engineers` policy:

```hcl
# Add additional permissions
statement {
  sid    = "AdditionalService"
  effect = "Allow"
  actions = [
    "service:Action",
  ]
  resources = ["*"]
}
```

### Adding New Groups

Add new groups and permission sets in `main.tf`:

```hcl
resource "aws_identitystore_group" "new_group" {
  identity_store_id = local.identity_store_id
  display_name      = "NewGroup"
  description       = "Description of the new group"
}

resource "aws_ssoadmin_permission_set" "new_group" {
  name             = "NewGroupAccess"
  description      = "Custom permissions for new group"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
}
```

## Troubleshooting

### Error: "Identity Center not enabled"

Ensure IAM Identity Center is enabled in your management account:

```bash
aws sso-admin list-instances
```

### Error: "Access denied"

Ensure you're running Terraform with credentials that have permissions to manage IAM Identity Center resources in the management account.

### Users not seeing accounts

1. Verify permission sets are assigned to accounts
2. Check that users are members of the groups
3. Ensure IAM Identity Center is properly synced

## References

- [IAM Identity Center Documentation](https://docs.aws.amazon.com/singlesignon/latest/userguide/what-is.html)
- [EKS IAM Roles](https://docs.aws.amazon.com/eks/latest/userguide/security-iam.html)
- [AWS Organizations](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_introduction.html)
- [Terraform AWS Provider - SSO Admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_permission_set)
