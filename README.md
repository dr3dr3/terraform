# Terraform Repository

## Workflow

Before creating "stacks" under environments and infrastructure layers, start with creating a small composable module.

1. Start by creating initial draft in `/terraform-examples` folder (get it working via Terraform init/plan/apply/destroy)
1. Create a test for the module under a `/terraform-tests` folder

## Local Development

### Setup Steps

1. **Install 1Password CLI** (for secure secret injection)
   - Download from: [1Password CLI](https://developer.1password.com/docs/cli/get-started/)
   - Sign in: `op signin`

2. **Inject Terraform Variables**
   - Run `./scripts/inject-tfvars.sh` to populate `.tfvars` files from `.tfvars.example` templates
   - This uses 1Password to inject secrets without committing them to git
   - See [1Password tfvars injection guide](docs/how-to-guides/1password-tfvars-injection.md) for details

3. **Terraform Cloud Authentication**
   - Run `terraform login` and provide your TF Cloud User Token (under your Account Settings)

## Git Repositories

- [Terraform Repository](https://github.com/dr3dr3/terraform) - Main repository with both Terraform code and documentation
- [Terraform Module Repository](https://github.com/dr3dr3/terraform-modules) - Versioned (via tags) modules used in the above repository

### Folder Structure - Terraform Repository

```markdown
terraform/
├── env-development/
│   ├── applications-layer/
│   │   ├── networking/
│   │   ├── sample-web-app/
│   │   └── eks-learning-cluster/
│   ├── foundation-layer/
│   └── platform-layer/
├── env-staging/
│   ├── applications-layer/
│   ├── foundation-layer/
│   └── platform-layer/
├── env-production/
│   ├── applications-layer/
│   ├── foundation-layer/
│   └── platform-layer/
└── env-management/
    ├── foundation-layer/
    └── platform-layer/
```

### Git Branching

- Trunk-Based Development

## CI/CD Pipeline

- TBD

## Terraform Cloud

### Terrafrom Projects

Mapped to environment and infrastructure layer, which aligns to the folder structure in the main Terraform repository.

- Development - Applications
- Development - Foundation
- Development - Platform
- Staging - Applications
- Staging - Foundation
- Staging - Platform
- Production - Applications
- Production - Foundation
- Production - Platform
- Management - Foundation
- Management - Platform

### Terraform Workspaces

Each project maps to the Terraform repositories folder structure:

| Project | Folder |
| ------- | ------ |
| development-applications | /terraform/env-development/applications-layer/ |
| etc | etc |
