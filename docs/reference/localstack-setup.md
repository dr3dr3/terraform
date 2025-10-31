# LocalStack Setup Guide

## Overview

LocalStack is a fully functional local AWS cloud stack that allows you to develop and test your cloud and Terraform applications offline without incurring AWS costs.

## Architecture

This devcontainer is configured to use **Docker-outside-of-Docker**, which means:
- Your devcontainer uses the host's Docker daemon
- LocalStack containers run as siblings to your devcontainer, not nested inside
- The Docker socket is mounted from the host into the devcontainer

## Prerequisites

- Docker must be running on your host machine
- The devcontainer must be rebuilt after configuration changes

## Installation

The devcontainer is already configured with:
- Docker CLI (for controlling the host's Docker daemon)
- Docker Compose (for managing multi-container applications)
- LocalStack CLI (for managing LocalStack)
- `awslocal` CLI (AWS CLI wrapper for LocalStack)

## Starting LocalStack

### Method 1: Using Docker Compose (Recommended)

```bash
# Start LocalStack in detached mode
docker compose -f docker-compose.localstack.yml up -d

# Check status
docker compose -f docker-compose.localstack.yml ps

# View logs
docker compose -f docker-compose.localstack.yml logs -f

# Stop LocalStack
docker compose -f docker-compose.localstack.yml down
```

### Method 2: Using LocalStack CLI

```bash
# Start LocalStack
localstack start -d

# Check status
localstack status

# View logs
localstack logs

# Stop LocalStack
localstack stop
```

## Configuration

### Environment Variables

Configuration can be customized in `.localstack.env`:

- `DEBUG`: Enable debug mode (0=off, 1=on)
- `SERVICES`: AWS services to enable (comma-separated or "all")
- `PERSISTENCE`: Enable data persistence across restarts (0=off, 1=on)
- `LAMBDA_EXECUTOR`: Lambda execution mode (docker, docker-reuse, or local)

### Common Services

```bash
# Enable specific services
SERVICES=s3,dynamodb,lambda,ec2,iam,sts,cloudformation

# Or enable all services
SERVICES=all
```

## Using LocalStack with Terraform

### Provider Configuration

Configure the AWS provider to point to LocalStack endpoints. See `examples/localstack-provider.tf` for a complete example:

```hcl
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3             = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    # Add other services as needed
  }
}
```

### Testing Workflow

1. **Start LocalStack**:
   ```bash
   docker compose -f docker-compose.localstack.yml up -d
   ```

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Plan and Apply**:
   ```bash
   terraform plan
   terraform apply
   ```

4. **Verify Resources** using awslocal:
   ```bash
   # List S3 buckets
   awslocal s3 ls
   
   # List DynamoDB tables
   awslocal dynamodb list-tables
   
   # Describe EC2 instances
   awslocal ec2 describe-instances
   ```

5. **Clean Up**:
   ```bash
   terraform destroy
   docker compose -f docker-compose.localstack.yml down
   ```

## Testing AWS CLI Commands

LocalStack includes `awslocal`, which is a wrapper around the AWS CLI that automatically points to LocalStack endpoints:

```bash
# Create an S3 bucket
awslocal s3 mb s3://test-bucket

# List S3 buckets
awslocal s3 ls

# Upload a file
awslocal s3 cp ./test.txt s3://test-bucket/

# Create a DynamoDB table
awslocal dynamodb create-table \
  --table-name test-table \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

## Persistence

By default, LocalStack data is not persisted. To enable persistence:

1. Set `PERSISTENCE=1` in `.localstack.env`
2. Data will be saved to `./volume` directory
3. Data persists across container restarts

```bash
# Enable persistence
echo "PERSISTENCE=1" >> .localstack.env

# Restart LocalStack
docker compose -f docker-compose.localstack.yml down
docker compose -f docker-compose.localstack.yml up -d
```

## Troubleshooting

### Check LocalStack Health

```bash
# Using curl
curl http://localhost:4566/_localstack/health | jq

# Using LocalStack CLI
localstack status
```

### View Logs

```bash
# Docker Compose
docker compose -f docker-compose.localstack.yml logs -f

# LocalStack CLI
localstack logs
```

### Port Conflicts

If port 4566 is already in use:
1. Stop the conflicting service
2. Or modify the port mapping in `docker-compose.localstack.yml`

### Docker Socket Issues

If you see "Cannot connect to Docker daemon" errors:
1. Ensure Docker is running on your host
2. Rebuild the devcontainer to pick up the socket mount
3. Verify socket permissions: `ls -l /var/run/docker.sock`

## Limitations

### LocalStack Community vs Pro

The free Community edition supports most common AWS services but has limitations:
- Some advanced features require LocalStack Pro
- IAM enforcement is limited in Community edition
- Some services have partial implementations

See the [LocalStack coverage documentation](https://docs.localstack.cloud/references/coverage/) for details.

### Service Parity

LocalStack emulates AWS services but may not be 100% identical:
- Always test in real AWS before production deployment
- Some edge cases or advanced features may behave differently
- Regional differences are not fully emulated

## Best Practices

1. **Start fresh for each test session** to avoid state contamination:
   ```bash
   docker compose -f docker-compose.localstack.yml down -v
   docker compose -f docker-compose.localstack.yml up -d
   ```

2. **Use separate provider configurations** for LocalStack and real AWS:
   - Create `provider-local.tf` for LocalStack
   - Create `provider-aws.tf` for real AWS
   - Use Terraform workspaces or separate directories

3. **Test incrementally**:
   - Start with simple resources (S3, DynamoDB)
   - Gradually add more complex resources
   - Verify each resource before proceeding

4. **Monitor resource usage**:
   - LocalStack can be resource-intensive
   - Limit enabled services to what you need
   - Use `docker stats` to monitor container resources

## Additional Resources

- [LocalStack Documentation](https://docs.localstack.cloud/)
- [LocalStack GitHub](https://github.com/localstack/localstack)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS CLI with LocalStack](https://docs.localstack.cloud/user-guide/integrations/aws-cli/)

## Next Steps

1. Rebuild your devcontainer to apply the configuration changes
2. Start LocalStack using one of the methods above
3. Try the example in `examples/localstack-provider.tf`
4. Adapt your existing Terraform code to work with LocalStack
