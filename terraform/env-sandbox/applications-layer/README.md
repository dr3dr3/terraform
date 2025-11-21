# Sandbox Applications Layer

## Purpose

The Applications Layer in Sandbox is for testing application infrastructure:

- Application deployment patterns
- Container orchestration testing
- Serverless architecture experiments
- Application-specific databases
- Service-to-service communication patterns

## Characteristics

- **Application-Focused**: Infrastructure that directly supports applications
- **Integration Testing**: Test how applications interact with platform
- **Realistic Workloads**: Simulate production-like application scenarios
- **Temporary**: Can be torn down after testing

## When to Use

Use this layer to test:

- New application deployment patterns
- Container configurations
- Application auto-scaling
- Database-per-service patterns
- API Gateway configurations
- Application security policies

## Example Structure

```text
applications-layer/
├── test-app-a/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
├── test-app-b/
└── integration-tests/
```

## Dependencies

Applications layer typically depends on:

- Foundation layer (networking)
- Platform layer (EKS, shared services)

```bash
data "terraform_remote_state" "foundation" {
  backend = "remote"
  config = {
    organization = "Datafaced"
    workspaces = {
      name = "sandbox-foundation-iam-roles"
    }
  }
}

data "terraform_remote_state" "platform" {
  backend = "remote"
  config = {
    organization = "Datafaced"
    workspaces = {
      name = "sandbox-platform"
    }
  }
}

# Use outputs from other layers
cluster_name = data.terraform_remote_state.platform.outputs.eks_cluster_name
vpc_id       = data.terraform_remote_state.foundation.outputs.vpc_id
```

## Testing Workflows

### 1. Deploy Test Application

```bash
cd applications-layer/test-app/
terraform init
terraform apply
```

### 2. Run Integration Tests

```bash
# Deploy application
terraform apply -auto-approve

# Run tests against deployed app
./run-integration-tests.sh

# Review results
cat test-results.json

# Clean up
terraform destroy -auto-approve
```

### 3. Load Testing

```bash
# Deploy with scaling configuration
terraform apply -var="min_replicas=2" -var="max_replicas=10"

# Run load test
./run-load-test.sh --target-url=$APP_URL --duration=5m

# Observe scaling behavior
kubectl get hpa --watch
```

## Best Practices

- **Name Clearly**: Use descriptive names like `test-api-gateway-auth`
- **Document Purpose**: README explaining what you're testing
- **Set Expiration**: Tag with `ExpiresOn` date
- **Clean Up**: Destroy when done testing
- **Use Synthetic Data**: Never use production data

## Integration Testing

Example integration test structure:

```text
applications-layer/integration-tests/
├── main.tf                    # Deploy test app + dependencies
├── tests/
│   ├── test_api_endpoints.py
│   ├── test_database_connection.py
│   └── test_service_mesh.py
├── fixtures/
│   └── test-data.json
└── run-tests.sh
```

## Common Test Scenarios

### API Gateway + Lambda

```bash
module "test_api" {
  source = "../../../terraform-modules/api-lambda"
  
  api_name = "sandbox-test-api"
  environment = "sandbox"
  
  # Test-specific configuration
  enable_cors = true
  enable_auth = false  # For testing
  log_level   = "DEBUG"
}
```

### ECS Service with ALB

```bash
module "test_service" {
  source = "../../../terraform-modules/ecs-service"
  
  service_name = "sandbox-test-service"
  environment  = "sandbox"
  
  # Small for testing
  desired_count = 1
  cpu          = "256"
  memory       = "512"
}
```

### Kubernetes Deployment

```bash
resource "kubernetes_deployment" "test_app" {
  metadata {
    name = "test-app"
    labels = {
      app = "test"
      environment = "sandbox"
    }
  }
  
  spec {
    replicas = 1
    
    selector {
      match_labels = {
        app = "test"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "test"
        }
      }
      
      spec {
        container {
          name  = "app"
          image = "nginx:latest"  # Or your test image
        }
      }
    }
  }
}
```

## Troubleshooting

### Issue: Can't Connect to Service

Check:

1. Security groups allow traffic
2. Service is running (`kubectl get pods`)
3. LoadBalancer has healthy targets
4. DNS resolves correctly

### Issue: Tests Failing

Check:

1. Resources fully deployed (not still creating)
2. Test data is valid
3. Dependencies are met
4. Timeouts are appropriate
5. Check application logs

## Cost Optimization

- Use smallest instance types that work
- Single replica for most tests
- Destroy resources after testing
- Schedule tests during off-peak hours
- Use spot instances where possible

## Related Documentation

- [Sandbox Environment README](../README.md)
- [Guide to Testing Terraform](../../../docs/explanations/guide-to-testing-terraform.md)
- [Application Layer Patterns](../../../docs/reference/architecture-decision-register/ADR-003-infra-layering-repository-structure.md)
