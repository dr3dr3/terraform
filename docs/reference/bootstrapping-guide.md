# Terraform Cloud Bootstrapping Guide for Cloud Providers

The bootstrapping process is the "chicken and egg" problem: Terraform needs permissions to create resources, but those permissions must be created first. Here's a comprehensive guide for the manual "Click-Ops" required before Terraform can take over.

## General Bootstrapping Philosophy

**What needs to be done manually:**
1. Create initial cloud accounts/projects
2. Create authentication mechanisms for Terraform
3. Set up Terraform Cloud organization and workspaces
4. Establish initial admin access
5. Create the first state backend connection

**After bootstrapping, Terraform manages:**
- All infrastructure resources
- IAM roles and policies (except the bootstrap role itself)
- Additional workspaces and projects
- Everything else

---

## AWS Bootstrapping Process

### Phase 1: AWS Console Setup (Click-Ops)

#### Step 1: Create AWS Accounts
```
Manual Steps in AWS Organizations Console:
1. Sign in to AWS Management Console (root account)
2. Navigate to AWS Organizations
3. Create organizational units (OUs):
   - Development
   - Staging  
   - Production
4. Create member accounts:
   - Click "Add an AWS account"
   - Create: dev-account, staging-account, prod-account
   - Note the 12-digit account IDs
```

#### Step 2: Enable Required AWS Services
```
In each account (Dev, Staging, Production):
1. Sign in to the account
2. Navigate to IAM → Identity providers
3. Ensure the account is ready for OIDC setup
```

#### Step 3: Create Initial Admin User (Optional but Recommended)
```
For initial setup only:
1. IAM → Users → Create user
2. Username: terraform-bootstrap-admin
3. Attach policy: AdministratorAccess
4. Create access key → "Application running outside AWS"
5. Save Access Key ID and Secret Access Key securely
6. This will be deleted after OIDC is configured
```

### Phase 2: Terraform Cloud Setup (Click-Ops)

#### Step 1: Create Terraform Cloud Organization
```
1. Navigate to https://app.terraform.io
2. Sign up or log in
3. Click "Create Organization"
4. Organization name: "your-company-name"
5. Email: your-admin-email@company.com
```

#### Step 2: Create Initial Project
```
1. In your TFC organization → Projects
2. Click "New Project"
3. Name: "aws-bootstrap"
4. Description: "Bootstrap infrastructure for AWS"
```

#### Step 3: Create Bootstrap Workspace
```
1. Projects → aws-bootstrap → "New Workspace"
2. Choose workflow: "CLI-driven workflow" (for initial setup)
3. Workspace name: "aws-oidc-bootstrap-dev"
4. Description: "Bootstrap OIDC and IAM for Dev account"
5. Click "Create workspace"
```

#### Step 4: Configure AWS Credentials (Temporary)
```
In the workspace:
1. Variables → Add variable
2. Add these as Environment Variables (sensitive):
   - AWS_ACCESS_KEY_ID: [from Step 3 above]
   - AWS_SECRET_ACCESS_KEY: [from Step 3 above]
   - AWS_DEFAULT_REGION: us-east-1

These will be removed after OIDC is set up.
```

### Phase 3: Bootstrap with Terraform

#### Step 1: Create Bootstrap Repository
```bash
# On your local machine
mkdir terraform-aws-bootstrap
cd terraform-aws-bootstrap

git init
```

#### Step 2: Create Bootstrap Configuration

**File: `bootstrap/dev/main.tf`**
```hcl
terraform {
  required_version = ">= 1.6"
  
  cloud {
    organization = "your-company-name"
    
    workspaces {
      name = "aws-oidc-bootstrap-dev"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = "dev"
      Bootstrap   = "true"
    }
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "tfc_organization" {
  description = "Terraform Cloud organization name"
  type        = string
}

variable "tfc_project_name" {
  description = "Terraform Cloud project name"
  type        = string
}

variable "tfc_workspace_name" {
  description = "Terraform Cloud workspace name for main infrastructure"
  type        = string
}
```

**File: `bootstrap/dev/oidc.tf`**
```hcl
# Create OIDC provider for Terraform Cloud
resource "aws_iam_openid_connect_provider" "tfc_provider" {
  url = "https://app.terraform.io"

  client_id_list = [
    "aws.workload.identity"
  ]

  thumbprint_list = [
    "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
  ]

  tags = {
    Name = "terraform-cloud-oidc"
  }
}

# Create IAM role for Terraform Cloud to assume
resource "aws_iam_role" "tfc_role" {
  name = "TerraformCloud-${var.environment}-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.tfc_provider.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "app.terraform.io:aud" = "aws.workload.identity"
          }
          StringLike = {
            # Restrict to specific organization/project/workspace
            "app.terraform.io:sub" = "organization:${var.tfc_organization}:project:${var.tfc_project_name}:workspace:${var.tfc_workspace_name}:run_phase:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "TerraformCloud-${var.environment}-Role"
  }
}

# Attach appropriate policies
resource "aws_iam_role_policy_attachment" "tfc_policy" {
  role       = aws_iam_role.tfc_role.name
  policy_arn = var.environment == "dev" ? "arn:aws:iam::aws:policy/PowerUserAccess" : aws_iam_policy.tfc_custom_policy[0].arn
}

# Custom policy for staging/production
resource "aws_iam_policy" "tfc_custom_policy" {
  count = var.environment != "dev" ? 1 : 0
  
  name        = "TerraformCloud-${var.environment}-Policy"
  description = "Custom policy for Terraform Cloud in ${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "cloudwatch:*",
          "s3:*",
          "rds:*",
          "dynamodb:*",
          "lambda:*",
          "logs:*",
          "sns:*",
          "sqs:*",
          "iam:Get*",
          "iam:List*",
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:PutRolePolicy",
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}

# Guardrails - prevent deletion of OIDC setup
resource "aws_iam_role_policy" "tfc_guardrails" {
  name = "PreventOIDCDeletion"
  role = aws_iam_role.tfc_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Deny"
        Action = [
          "iam:DeleteOpenIDConnectProvider",
          "iam:DeleteRole",
          "iam:DeleteRolePolicy"
        ]
        Resource = [
          aws_iam_openid_connect_provider.tfc_provider.arn,
          aws_iam_role.tfc_role.arn
        ]
      }
    ]
  })
}

variable "environment" {
  description = "Environment name"
  type        = string
}
```

**File: `bootstrap/dev/outputs.tf`**
```hcl
output "tfc_role_arn" {
  description = "ARN of the role for Terraform Cloud to assume"
  value       = aws_iam_role.tfc_role.arn
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.tfc_provider.arn
}

output "next_steps" {
  description = "Next steps to complete setup"
  value = <<-EOT
    
    Bootstrap complete! Next steps:
    
    1. In Terraform Cloud workspace '${var.tfc_workspace_name}':
       - Add environment variable: TFC_AWS_PROVIDER_AUTH = true
       - Add environment variable: TFC_AWS_RUN_ROLE_ARN = ${aws_iam_role.tfc_role.arn}
    
    2. Remove the temporary AWS access keys from the bootstrap workspace
    
    3. Test OIDC authentication by running a plan
    
    4. Repeat this process for staging and production accounts
    
  EOT
}
```

**File: `bootstrap/dev/terraform.tfvars`**
```hcl
environment        = "dev"
tfc_organization   = "your-company-name"
tfc_project_name   = "aws-infrastructure"
tfc_workspace_name = "app-dev"
aws_region         = "us-east-1"
```

#### Step 3: Run Bootstrap
```bash
# Initialize and apply
terraform init
terraform plan
terraform apply

# Note the outputs, especially the role ARN
```

### Phase 4: Switch to OIDC (Click-Ops)

#### In Terraform Cloud Console:
```
1. Navigate to your main workspace (app-dev)
2. Variables → Environment Variables
3. Add:
   - Key: TFC_AWS_PROVIDER_AUTH
   - Value: true
   
4. Add:
   - Key: TFC_AWS_RUN_ROLE_ARN  
   - Value: [ARN from bootstrap output]

5. Remove the temporary AWS access keys

6. Test by running a plan in the workspace
```

### Phase 5: Clean Up Bootstrap Credentials
```
Back in AWS Console:
1. IAM → Users → terraform-bootstrap-admin
2. Delete access key
3. Delete user (optional - can keep for emergency access)
```

---

## GCP Bootstrapping Process

### Phase 1: GCP Console Setup (Click-Ops)

#### Step 1: Create GCP Organization and Projects
```
1. Navigate to https://console.cloud.google.com
2. Create organization (if not exists)
3. Create projects:
   - Click "Create Project"
   - Project names: 
     * company-dev
     * company-staging  
     * company-production
   - Note the Project IDs
```

#### Step 2: Enable Required APIs
```
In each project:
1. Navigate to "APIs & Services" → "Library"
2. Enable these APIs:
   - Cloud Resource Manager API
   - Identity and Access Management (IAM) API
   - Service Usage API
   - Cloud Storage API (for state bucket)
```

#### Step 3: Create Service Account (Temporary)
```
In the dev project:
1. IAM & Admin → Service Accounts
2. Create Service Account:
   - Name: terraform-bootstrap
   - ID: terraform-bootstrap
3. Grant roles:
   - Project → Owner (temporary)
4. Create key:
   - Actions → Manage Keys → Add Key → Create new key
   - Type: JSON
   - Save the JSON file securely
```

### Phase 2: Terraform Cloud Setup

Same as AWS Phase 2, but for GCP workspaces.

### Phase 3: Bootstrap Configuration

**File: `bootstrap/gcp-dev/main.tf`**
```hcl
terraform {
  required_version = ">= 1.6"
  
  cloud {
    organization = "your-company-name"
    
    workspaces {
      name = "gcp-oidc-bootstrap-dev"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "tfc_organization" {
  description = "Terraform Cloud organization"
  type        = string
}

variable "tfc_project_name" {
  description = "Terraform Cloud project name"
  type        = string
}

variable "tfc_workspace_name" {
  description = "Terraform Cloud workspace name"
  type        = string
}
```

**File: `bootstrap/gcp-dev/oidc.tf`**
```hcl
# Create Workload Identity Pool
resource "google_iam_workload_identity_pool" "tfc_pool" {
  project                   = var.gcp_project_id
  workload_identity_pool_id = "terraform-cloud-pool"
  display_name              = "Terraform Cloud Pool"
  description               = "Workload Identity Pool for Terraform Cloud"
}

# Create Workload Identity Provider
resource "google_iam_workload_identity_pool_provider" "tfc_provider" {
  project                            = var.gcp_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.tfc_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "terraform-cloud-provider"
  display_name                       = "Terraform Cloud Provider"
  
  attribute_mapping = {
    "google.subject"                  = "assertion.sub"
    "attribute.aud"                   = "assertion.aud"
    "attribute.terraform_run_phase"   = "assertion.terraform_run_phase"
    "attribute.terraform_workspace_id" = "assertion.terraform_workspace_id"
  }
  
  attribute_condition = "assertion.sub.startsWith(\"organization:${var.tfc_organization}:project:${var.tfc_project_name}:workspace:${var.tfc_workspace_name}\")"
  
  oidc {
    issuer_uri = "https://app.terraform.io"
  }
}

# Create Service Account for Terraform Cloud
resource "google_service_account" "tfc_service_account" {
  project      = var.gcp_project_id
  account_id   = "terraform-cloud-${var.environment}"
  display_name = "Terraform Cloud ${var.environment}"
  description  = "Service account for Terraform Cloud in ${var.environment}"
}

# Allow Terraform Cloud to impersonate the service account
resource "google_service_account_iam_member" "tfc_workload_identity" {
  service_account_id = google_service_account.tfc_service_account.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.tfc_pool.name}/attribute.terraform_workspace_id/${var.tfc_workspace_name}"
}

# Grant appropriate roles to the service account
resource "google_project_iam_member" "tfc_roles" {
  for_each = toset([
    "roles/compute.admin",
    "roles/storage.admin",
    "roles/iam.serviceAccountUser",
    # Add other roles as needed
  ])
  
  project = var.gcp_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.tfc_service_account.email}"
}

variable "environment" {
  description = "Environment name"
  type        = string
}
```

**File: `bootstrap/gcp-dev/outputs.tf`**
```hcl
output "service_account_email" {
  description = "Service account email for Terraform Cloud"
  value       = google_service_account.tfc_service_account.email
}

output "workload_identity_provider" {
  description = "Workload identity provider name"
  value       = google_iam_workload_identity_pool_provider.tfc_provider.name
}

output "next_steps" {
  description = "Next steps"
  value = <<-EOT
    
    Bootstrap complete! Next steps:
    
    1. In Terraform Cloud workspace '${var.tfc_workspace_name}':
       - Add environment variable: TFC_GCP_PROVIDER_AUTH = true
       - Add environment variable: TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL = ${google_service_account.tfc_service_account.email}
       - Add environment variable: TFC_GCP_WORKLOAD_PROVIDER_NAME = ${google_iam_workload_identity_pool_provider.tfc_provider.name}
    
    2. Remove the temporary service account key JSON
    
    3. Test OIDC authentication
    
  EOT
}
```

### Phase 4: Configure TFC for GCP OIDC
```
In Terraform Cloud workspace:
1. Add environment variable: TFC_GCP_PROVIDER_AUTH = true
2. Add environment variable: TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL = [from output]
3. Add environment variable: TFC_GCP_WORKLOAD_PROVIDER_NAME = [from output]
4. Add environment variable: TFC_GCP_PROJECT_NUMBER = [project number]
5. Remove GOOGLE_CREDENTIALS variable
```

---

## Azure Bootstrapping Process

### Phase 1: Azure Portal Setup (Click-Ops)

#### Step 1: Create Resource Groups
```
1. Navigate to https://portal.azure.com
2. Resource Groups → Create
3. Create resource groups:
   - rg-dev-eastus
   - rg-staging-eastus
   - rg-production-eastus
```

#### Step 2: Create Service Principal (Temporary)
```
1. Azure Active Directory → App registrations
2. New registration:
   - Name: terraform-bootstrap
   - Click "Register"
3. Note the Application (client) ID
4. Certificates & secrets → New client secret
   - Description: bootstrap
   - Expires: 3 months
   - Copy the secret value (shown only once)
5. Subscriptions → [Your subscription] → Access control (IAM)
6. Add role assignment:
   - Role: Contributor
   - Assign access to: User, group, or service principal
   - Select: terraform-bootstrap
```

### Phase 2 & 3: Similar to AWS/GCP

### Phase 4: Bootstrap Configuration

**File: `bootstrap/azure-dev/oidc.tf`**
```hcl
data "azurerm_subscription" "current" {}

data "azuread_client_config" "current" {}

# Create Azure AD Application
resource "azuread_application" "tfc_app" {
  display_name = "terraform-cloud-${var.environment}"
  owners       = [data.azuread_client_config.current.object_id]
}

# Create Service Principal
resource "azuread_service_principal" "tfc_sp" {
  client_id = azuread_application.tfc_app.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# Configure Federated Identity Credential for OIDC
resource "azuread_application_federated_identity_credential" "tfc_federated_credential" {
  application_id = azuread_application.tfc_app.id
  display_name   = "terraform-cloud-${var.environment}"
  description    = "Federated credential for Terraform Cloud"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://app.terraform.io"
  subject        = "organization:${var.tfc_organization}:project:${var.tfc_project_name}:workspace:${var.tfc_workspace_name}:run_phase:*"
}

# Assign role to service principal
resource "azurerm_role_assignment" "tfc_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.tfc_sp.object_id
}
```

**Outputs:**
```hcl
output "next_steps" {
  value = <<-EOT
    
    In Terraform Cloud workspace:
    - TFC_AZURE_PROVIDER_AUTH = true
    - TFC_AZURE_RUN_CLIENT_ID = ${azuread_application.tfc_app.client_id}
    - ARM_SUBSCRIPTION_ID = ${data.azurerm_subscription.current.subscription_id}
    - ARM_TENANT_ID = ${data.azurerm_subscription.current.tenant_id}
    
  EOT
}
```

---

## Complete Bootstrapping Checklist

### Pre-Bootstrap Checklist
- [ ] Cloud provider accounts created
- [ ] Terraform Cloud organization created
- [ ] Terraform Cloud project created
- [ ] Bootstrap workspace created in TFC
- [ ] Temporary credentials configured in TFC
- [ ] Git repository initialized

### During Bootstrap
- [ ] Bootstrap Terraform code written
- [ ] `terraform init` successful
- [ ] `terraform plan` reviewed
- [ ] `terraform apply` successful
- [ ] OIDC provider created
- [ ] IAM role/service account created
- [ ] Outputs noted (role ARNs, etc.)

### Post-Bootstrap
- [ ] OIDC variables added to TFC workspace
- [ ] Temporary credentials removed from TFC
- [ ] Test plan runs successfully with OIDC
- [ ] Bootstrap user/service account deleted (or access keys removed)
- [ ] Bootstrap workspace documentation updated
- [ ] Repeat for other environments

### Ongoing Management
- [ ] Never manually modify OIDC provider/role
- [ ] Keep bootstrap workspace for emergency access
- [ ] Regularly audit IAM permissions
- [ ] Maintain bootstrap code in version control

---

## Common Pitfalls

1. **Deleting the OIDC provider accidentally**: Always add deny policies
2. **Wrong thumbprint for TFC**: Use the documented thumbprint
3. **Subject claim too broad**: Always restrict to specific org/project/workspace
4. **Forgetting to enable APIs in GCP**: Bootstrap will fail
5. **Not saving temporary credentials**: You'll need them until OIDC works
6. **Applying bootstrap from local machine**: Use TFC for consistency

This bootstrapping process establishes the foundation for secure, automated infrastructure management with no long-lived credentials.