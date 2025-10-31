# ADR-004: Infrastructure Tooling Separation - Terraform, Helm, and Kubernetes CRDs

**Status:** Proposed  
**Date:** 2025-10-28  
**Decision Makers:** Platform Engineering Team, Engineering Leadership  
**Related ADRs:** ADR-001 (Terraform Cloud), ADR-003 (Infrastructure Layering)

---

## Context and Problem Statement

Our organization is building a cloud-native platform on AWS EKS Fargate with approximately 50 microservices. We need to make a clear decision about which infrastructure tools to use for different aspects of our platform management. The key question is:

**How do we appropriately separate concerns between Terraform, Helm, and Kubernetes native resources (CRDs) to create a maintainable, scalable, and developer-friendly infrastructure?**

### Current Environment
- **Cloud Provider:** AWS (with multi-cloud future considerations)
- **Container Orchestration:** AWS EKS Fargate
- **Microservices:** ~50 C# microservices
- **IaC Tool:** Terraform with Terraform Cloud
- **Current State:** Infrastructure layering strategy defined (ADR-003)
- **Team Structure:** Platform Engineering team + Engineering Squads

### Key Concerns
1. **Cognitive Load:** Engineers shouldn't need to learn all tools deeply
2. **Separation of Concerns:** Clear boundaries between infrastructure types
3. **Change Frequency:** Different infrastructure changes at different rates
4. **Maintainability:** Avoiding duplication and tool overlap
5. **Developer Experience:** Provide "golden paths" for common operations
6. **Scalability:** Solution must work from 50 to 200+ microservices

---

## Decision Drivers

### Technical Drivers
- **Tool Strengths:** Each tool (Terraform, Helm, K8s) excels at different problems
- **AWS EKS Fargate:** Serverless K8s that abstracts node management
- **Multi-cloud Future:** Potential expansion beyond AWS
- **Existing Terraform Investment:** Already using Terraform Cloud and infrastructure layering

### Organizational Drivers
- **Team Expertise:** Engineers have varying infrastructure knowledge
- **Platform Engineering Model:** Platform team provides self-service capabilities
- **Continuous Delivery:** Need rapid, frequent deployments without infrastructure changes
- **Security & Compliance:** Guardrails and policy enforcement required

### Change Frequency Considerations
- **Management Infrastructure:** Changes rarely (VPCs, IAM, networking)
- **Cluster Infrastructure:** Changes occasionally (EKS clusters, node groups)
- **Foundation Services:** Changes monthly (Istio, Kyverno, monitoring)
- **Application Infrastructure:** Changes frequently (per service/feature)
- **Application Code:** Changes multiple times daily

---

## Considered Options

### Option 1: Terraform for Everything
**Description:** Use Terraform to manage all infrastructure including Kubernetes resources via the Kubernetes provider.

**Pros:**
- ✅ Single tool and workflow
- ✅ Consistent state management
- ✅ Strong AWS resource management
- ✅ Good for infrastructure teams

**Cons:**
- ❌ Poor developer experience for K8s resources
- ❌ Slow deployment cycles for application changes
- ❌ Terraform not designed for K8s-native workflows
- ❌ Kubernetes provider has limitations
- ❌ Doesn't leverage K8s' orchestration strengths
- ❌ State file bottleneck for frequent changes

### Option 2: Kubernetes CRDs for Everything
**Description:** Use Kubernetes native resources and custom operators (Crossplane, ACK) for all infrastructure.

**Pros:**
- ✅ Kubernetes-native approach
- ✅ Good for K8s-centric organizations
- ✅ Declarative and GitOps-friendly
- ✅ Unified API surface

**Cons:**
- ❌ CRDs still maturing for AWS resources
- ❌ Limited multi-cloud support
- ❌ Steep learning curve for non-K8s experts
- ❌ Platform team must maintain complex operators
- ❌ Harder to manage foundational infrastructure (VPCs, IAM)
- ❌ Less mature tooling for drift detection
- ❌ Circular dependency: need K8s to create K8s cluster

### Option 3: Helm for All K8s Resources
**Description:** Use Helm charts for all Kubernetes deployments, including infrastructure components.

**Pros:**
- ✅ Strong packaging and versioning
- ✅ Good templating capabilities
- ✅ Rich ecosystem of charts

**Cons:**
- ❌ Not designed for AWS resource management
- ❌ State management is weaker than Terraform
- ❌ Complex for simple deployments
- ❌ Doesn't solve AWS infrastructure problem
- ❌ Release management overhead

### Option 4: Layered Approach - Terraform + Helm + Kubernetes (RECOMMENDED)
**Description:** Use each tool for what it does best, with clear boundaries:
- **Terraform:** AWS infrastructure and EKS clusters
- **Helm:** Foundation K8s services (Istio, Kyverno, etc.)
- **Kubernetes Native:** Application deployments and app-specific infrastructure

**Pros:**
- ✅ Each tool used for its strengths
- ✅ Clear separation of concerns
- ✅ Optimized for different change frequencies
- ✅ Best developer experience
- ✅ Leverages existing Terraform investment
- ✅ Scales well with organization growth
- ✅ Easier to provide self-service
- ✅ Natural boundaries between platform and app teams

**Cons:**
- ⚠️ Multiple tools to understand (but at different depths)
- ⚠️ Need clear documentation and boundaries
- ⚠️ Requires coordination between tool usage

---

## Decision

**We will adopt Option 4: Layered Approach with Terraform, Helm, and Kubernetes CRDs**

This decision provides:
1. **Clear tool boundaries** based on infrastructure type and change frequency
2. **Optimal developer experience** by reducing cognitive load
3. **Scalability** for our growing microservices architecture
4. **Alignment** with our existing infrastructure layering strategy (ADR-003)

---

## Detailed Approach

### Layer 1: Terraform - Foundation & Cluster Management

**Scope:** AWS infrastructure and EKS cluster provisioning

**What Terraform Manages:**
- AWS foundational infrastructure (VPCs, subnets, security groups)
- IAM roles and policies
- RDS databases (Postgres instances)
- AWS managed services (SNS, SES, Kinesis, Secrets Manager)
- EKS Fargate clusters and profiles
- AWS networking (Service Connect, VPC endpoints)
- AWS ECR repositories

**Why Terraform for This:**
- ✅ Best-in-class AWS resource management
- ✅ Terraform Cloud provides state management, workflows, and governance
- ✅ Multi-cloud ready (potential Azure/GCP expansion)
- ✅ Platform team expertise already exists
- ✅ Aligns with existing infrastructure layering (ADR-003)
- ✅ Changes infrequently (quarterly/monthly)

**Terraform Workspace Structure:**
```
terraform-infrastructure/
├── 01-foundation/          # Managed by Terraform Cloud
│   ├── networking/
│   ├── iam/
│   └── secrets/
├── 02-platform/            # Managed by Terraform Cloud
│   ├── eks-clusters/
│   ├── ecr/
│   └── rds/
└── 03-shared-services/     # Managed by Terraform Cloud
    ├── data-services/
    └── messaging/
```

**Engineer Interaction:**
- ❌ **Engineers do NOT directly modify Terraform**
- ✅ Platform team provides Terraform modules
- ✅ Engineers request infrastructure via self-service (Compass, portal, or PR)

---

### Layer 2: Helm - Foundation Kubernetes Services

**Scope:** Core Kubernetes platform capabilities and cluster-wide services

**What Helm Manages:**
- **Service Mesh:** Istio (traffic management, security, observability)
- **Policy Engine:** Kyverno (admission control, policy enforcement)
- **Observability Stack:** Datadog agents, Fluent Bit
- **Certificate Management:** cert-manager
- **Ingress Controllers:** AWS Load Balancer Controller
- **Security Tools:** Falco, network policies
- **GitOps Tools:** ArgoCD (if adopted)

**Why Helm for This:**
- ✅ Designed for complex K8s application packaging
- ✅ Excellent for multi-resource deployments with interdependencies
- ✅ Strong versioning and rollback capabilities
- ✅ Rich ecosystem of maintained charts (Istio, Kyverno, etc.)
- ✅ Values-based configuration for different environments
- ✅ Changes monthly/quarterly (stable foundation)

**Helm Repository Structure:**
```
helm-charts/
├── istio/
│   ├── Chart.yaml
│   └── values-{env}.yaml
├── kyverno/
│   ├── Chart.yaml
│   └── values-{env}.yaml
├── datadog/
│   ├── Chart.yaml
│   └── values-{env}.yaml
└── cert-manager/
    ├── Chart.yaml
    └── values-{env}.yaml
```

**Deployment Approach:**
```bash
# Platform team deploys via CI/CD or ArgoCD
helm upgrade --install istio istio/istiod \
  -f values-production.yaml \
  --namespace istio-system \
  --create-namespace
```

**Engineer Interaction:**
- ❌ **Engineers do NOT directly deploy Helm charts**
- ✅ Platform team manages foundation services
- ✅ Engineers consume services (e.g., Istio VirtualServices, Kyverno policies)
- ✅ Engineers may contribute to shared Helm charts via PR

---

### Layer 3: Kubernetes CRDs - Application Infrastructure

**Scope:** Application-specific infrastructure needs

**What Kubernetes CRDs Manage:**
- **Istio Resources:** VirtualServices, DestinationRules, Gateways
- **Service Configuration:** ConfigMaps, Secrets (app-specific)
- **Scaling Configuration:** HorizontalPodAutoscalers
- **Network Policies:** Application-specific network rules
- **Kyverno Policies:** Application-specific policy exceptions
- **External Secrets Operator:** Sync from AWS Secrets Manager

**Why K8s CRDs for This:**
- ✅ Changes frequently (per feature/service deployment)
- ✅ Kubernetes is designed for orchestration and runtime management
- ✅ Declarative and GitOps-friendly
- ✅ Fast reconciliation loops
- ✅ Native integration with K8s ecosystem
- ✅ Developers already working in K8s manifests

**Example CRD Usage:**
```yaml
# Application defines its routing needs
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: order-service
  namespace: production
spec:
  hosts:
  - order.example.com
  http:
  - route:
    - destination:
        host: order-service
        subset: v1
      weight: 90
    - destination:
        host: order-service
        subset: v2
      weight: 10
```

**Engineer Interaction:**
- ✅ **Engineers DO define application-specific CRDs**
- ✅ CRDs deployed alongside application manifests
- ✅ Platform provides templates and documentation
- ✅ Guardrails enforced via Kyverno policies

---

### Layer 4: Kubernetes Native - Application Deployments

**Scope:** Application code deployment and runtime configuration

**What Kubernetes Native Manages:**
- **Deployments:** Application pods and replicas
- **Services:** Internal service discovery
- **ConfigMaps/Secrets:** Application configuration
- **ServiceAccounts:** Application identity
- **PodDisruptionBudgets:** Availability requirements
- **ResourceQuotas:** Namespace resource limits (platform-managed)

**Why K8s Native for This:**
- ✅ Changes multiple times daily
- ✅ Kubernetes' core competency
- ✅ Fast, declarative updates
- ✅ Excellent scaling and health management
- ✅ No additional tooling needed
- ✅ CI/CD pipelines can directly apply manifests

**Deployment Structure:**
```
application-repo/
├── src/                    # Application code (C#)
├── Dockerfile
├── k8s/
│   ├── base/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       ├── dev/
│       ├── staging/
│       └── production/
└── .bitbucket-pipelines.yml
```

**Deployment Flow:**
```yaml
# BitBucket Pipeline
- step: deploy-to-production
    image: bitnami/kubectl:latest
    script:
      - kubectl apply -k k8s/overlays/production/
```

**Engineer Interaction:**
- ✅ **Engineers FULLY OWN application deployments**
- ✅ Apply manifests via CI/CD (BitBucket Pipelines)
- ✅ Use Kustomize for environment-specific configuration
- ✅ Platform provides manifest templates via service catalog

---

## Integration Patterns

### Pattern 1: Terraform Outputs → Helm Values

**Use Case:** Helm charts need to reference AWS resources created by Terraform

```hcl
# Terraform outputs
output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "sns_topic_arn" {
  value = aws_sns_topic.notifications.arn
}
```

```yaml
# Helm values.yaml references Terraform outputs
database:
  host: "{{ .Values.database.host }}"  # From Terraform output

# Deployed via:
helm install my-service ./chart \
  --set database.host="${TF_OUTPUT_RDS_ENDPOINT}"
```

### Pattern 2: Helm-Managed CRDs → Application Use

**Use Case:** Applications use CRDs provided by Helm-installed operators

```yaml
# 1. Platform installs Istio via Helm
helm install istio-base istio/base -n istio-system
helm install istiod istio/istiod -n istio-system

# 2. Application uses Istio CRDs
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-service
spec:
  hosts: ["my-service.example.com"]
  # ...
```

### Pattern 3: External Secrets Operator Bridge

**Use Case:** Bridge AWS Secrets Manager (Terraform) to K8s Secrets (app consumption)

```hcl
# 1. Terraform creates AWS secret
resource "aws_secretsmanager_secret" "db_password" {
  name = "production/order-service/db-password"
}
```

```yaml
# 2. Helm installs External Secrets Operator
helm install external-secrets external-secrets/external-secrets

# 3. Application defines ExternalSecret CRD
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: db-credentials
  data:
  - secretKey: password
    remoteRef:
      key: production/order-service/db-password

# 4. Application consumes as normal K8s Secret
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-credentials
      key: password
```

### Pattern 4: Kustomize for Environment Management

**Use Case:** Same application manifests across dev/staging/production

```yaml
# base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  replicas: 2  # Base value
  template:
    spec:
      containers:
      - name: app
        image: order-service:latest
        resources:
          requests:
            cpu: 100m
            memory: 128Mi

# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
- ../../base
replicas:
- name: order-service
  count: 10
images:
- name: order-service
  newTag: v1.2.3
patchesStrategicMerge:
- resources.yaml  # Override resource limits
```

---

## Decision Matrix: Which Tool When?

| Infrastructure Type | Tool | Owner | Change Frequency | Example |
|---------------------|------|-------|------------------|---------|
| AWS Networking | Terraform | Platform | Rarely | VPC, Subnets |
| AWS IAM | Terraform | Platform | Rarely | Roles, Policies |
| AWS Databases | Terraform | Platform | Monthly | RDS Postgres |
| AWS Services | Terraform | Platform | Monthly | SNS, SES, Kinesis |
| EKS Clusters | Terraform | Platform | Rarely | EKS Fargate |
| ECR Repositories | Terraform | Platform | Per Service | Container Registry |
| Service Mesh | Helm | Platform | Quarterly | Istio |
| Policy Engine | Helm | Platform | Quarterly | Kyverno |
| Observability | Helm | Platform | Monthly | Datadog, Fluent Bit |
| Ingress Controllers | Helm | Platform | Quarterly | AWS LB Controller |
| Routing Rules | CRDs (Istio) | Engineers | Per Deploy | VirtualService |
| Network Policies | CRDs (K8s) | Engineers | Per Service | NetworkPolicy |
| Scaling Config | CRDs (K8s) | Engineers | Per Service | HPA |
| Application Pods | K8s Native | Engineers | Daily | Deployment |
| Service Discovery | K8s Native | Engineers | Per Service | Service |
| App Configuration | K8s Native | Engineers | Per Deploy | ConfigMap |

---

## Golden Paths for Engineers

To minimize cognitive load, Platform Engineering will provide "golden paths" for common operations:

### Golden Path 1: New Microservice Bootstrap

**What Engineers Do:**
1. Run service scaffold CLI: `platform-cli new-service --name order-service --type api`
2. Generated repo includes:
   - Dockerfile
   - K8s manifests (Deployment, Service, HPA, Istio VirtualService)
   - BitBucket Pipeline for CI/CD
   - Kustomize structure for environments
3. Engineers modify code, push, and pipeline auto-deploys

**What Platform Provides:**
- Service template repository
- Pre-configured CI/CD pipeline
- K8s manifest templates with best practices
- Documentation and getting started guide

### Golden Path 2: Requesting Shared Infrastructure

**What Engineers Do:**
1. Open issue in Atlassian Compass: "Request RDS Database for Order Service"
2. Fill out standardized form (size, backup requirements, etc.)
3. Platform team provisions via Terraform
4. Connection details provided via AWS Secrets Manager
5. Engineers consume via External Secrets Operator

**What Platform Provides:**
- Self-service request portal (Compass)
- Terraform modules for common resources
- Standardized naming conventions
- Automated secret provisioning

### Golden Path 3: Configuring Traffic Routing

**What Engineers Do:**
1. Copy template from platform docs
2. Modify VirtualService CRD for their service
3. Commit to repo, pipeline applies manifest
4. Istio automatically handles routing

```yaml
# Template provided by platform
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: {{ service-name }}
spec:
  hosts:
  - {{ service-name }}.{{ domain }}
  http:
  - route:
    - destination:
        host: {{ service-name }}
```

**What Platform Provides:**
- Istio installed and configured (via Helm)
- VirtualService templates
- Documentation on routing patterns
- Guardrails via Kyverno to prevent mistakes

---

## Guardrails and Governance

To ensure safe and compliant infrastructure:

### Terraform Governance (via Terraform Cloud)
- **Policy as Code:** Sentinel policies for cost, security, compliance
- **Approval Workflows:** Changes to production require approval
- **Cost Estimation:** Show cost impact before apply
- **Access Control:** RBAC for who can apply changes
- **Audit Logs:** Track all infrastructure changes

### Kubernetes Governance (via Kyverno)
- **Resource Limits:** Enforce CPU/memory limits on all pods
- **Image Security:** Require images from approved registries (ECR)
- **Network Policies:** Deny all by default, require explicit allow
- **Label Requirements:** Enforce standard labels (team, service, environment)
- **Istio Configuration:** Validate VirtualService correctness

**Example Kyverno Policy:**
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: enforce
  rules:
  - name: check-cpu-memory
    match:
      resources:
        kinds:
        - Deployment
    validate:
      message: "CPU and memory limits are required"
      pattern:
        spec:
          template:
            spec:
              containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
```

### Helm Governance
- **Chart Versioning:** Semantic versioning for all charts
- **Values Validation:** JSON schema validation for values files
- **Deployment Control:** Platform team owns Helm releases
- **Environment Promotion:** Changes flow dev → staging → production

---

## Migration Strategy

### Phase 1: Foundation (Months 1-2)
**Goal:** Establish Terraform and Helm foundations

1. **Week 1-2: Terraform Setup**
   - Migrate existing EKS clusters to Terraform
   - Establish Terraform Cloud workspaces
   - Document Terraform module standards

2. **Week 3-4: Helm Deployment**
   - Install Istio via Helm
   - Install Kyverno via Helm
   - Install Datadog agents via Helm
   - Document Helm chart standards

**Success Criteria:**
- ✅ All EKS clusters managed by Terraform
- ✅ Foundation services (Istio, Kyverno) deployed via Helm
- ✅ Platform team can update foundation services via Helm

### Phase 2: Application Migration (Months 3-4)
**Goal:** Migrate 5 pilot applications to K8s native deployments

1. **Week 1: Template Creation**
   - Create service scaffold templates
   - Create Kustomize base manifests
   - Create BitBucket Pipeline templates

2. **Week 2-4: Pilot Migration**
   - Select 5 diverse microservices
   - Migrate CI/CD to new approach
   - Train squads on new workflow

**Success Criteria:**
- ✅ 5 services deploying via K8s manifests
- ✅ CI/CD pipelines using BitBucket + kubectl
- ✅ Engineers comfortable with new approach

### Phase 3: Full Rollout (Months 5-6)
**Goal:** Migrate all 50 microservices

1. **Weeks 1-8: Gradual Migration**
   - Migrate 8-10 services per week
   - Provide hands-on support to squads
   - Iterate on templates based on feedback

2. **Week 9-10: Optimization**
   - Refine golden paths
   - Improve documentation
   - Automate common tasks

**Success Criteria:**
- ✅ All 50 services on new approach
- ✅ Engineers self-sufficient with deployments
- ✅ Platform team focuses on self-service improvements

### Phase 4: Advanced Features (Months 7-12)
**Goal:** Implement advanced platform capabilities

- **External Secrets Operator:** Bridge AWS Secrets Manager
- **ArgoCD:** Consider GitOps deployment automation
- **Service Catalog:** Self-service infrastructure requests
- **Cost Optimization:** Analyze and optimize Fargate costs
- **Advanced Istio:** Traffic splitting, circuit breakers, retries

---

## Consequences

### Positive Consequences

**For Engineers:**
- ✅ **Lower Cognitive Load:** Only need deep K8s knowledge, not Terraform
- ✅ **Faster Deployments:** Direct K8s deployments vs. Terraform cycles
- ✅ **Golden Paths:** Templates and standards reduce decision fatigue
- ✅ **Self-Service:** Can deploy without platform team bottleneck
- ✅ **Better DX:** Tools designed for their use cases

**For Platform Team:**
- ✅ **Clear Boundaries:** Less context switching between tools
- ✅ **Right Tool:** Each tool used for what it does best
- ✅ **Scalability:** Can support 200+ microservices
- ✅ **Less Toil:** Fewer ad-hoc infrastructure requests
- ✅ **Better Governance:** Automated policies and guardrails

**For Organization:**
- ✅ **Velocity:** Faster feature delivery with fewer blockers
- ✅ **Reliability:** Consistent patterns reduce errors
- ✅ **Security:** Automated policy enforcement
- ✅ **Cost:** Right-sized resources with HPA and Fargate
- ✅ **Compliance:** Audit trails across all tools

### Negative Consequences

**Complexity:**
- ⚠️ **Multiple Tools:** Team must understand three tool ecosystems
- ⚠️ **Integration:** Need clear patterns for tool interactions
- ⚠️ **Documentation:** Must maintain docs for all three approaches

**Mitigation:**
- ✅ Provide clear decision matrix (documented above)
- ✅ Create golden paths that hide tool complexity
- ✅ Platform team abstracts complexity where possible
- ✅ Comprehensive onboarding and training

**Learning Curve:**
- ⚠️ **Initial Investment:** Team needs training on boundaries
- ⚠️ **Context Switching:** Platform team works across tools

**Mitigation:**
- ✅ Phase migration over 6 months
- ✅ Start with pilot projects
- ✅ Hands-on support during migration
- ✅ Templates reduce learning requirements

---

## Validation and Metrics

### Success Metrics

**Developer Velocity:**
- **Time to Deploy:** < 10 minutes from commit to production
- **Deployment Frequency:** 10+ deploys/day per team
- **Change Failure Rate:** < 15%
- **Mean Time to Recovery:** < 30 minutes

**Platform Health:**
- **Infrastructure Change Lead Time:** < 1 week for new resources
- **Foundation Service Uptime:** > 99.9%
- **Platform Team Toil:** < 20% of time on tickets

**Developer Experience:**
- **Self-Service Adoption:** > 80% of deploys self-service
- **Documentation Usage:** Docs accessed by 90% of engineers
- **Developer Satisfaction:** DORA/DevEx survey scores improve

### Validation Questions

**Every Quarter, Ask:**
1. Are engineers deploying without platform team help?
2. Are deployments faster than before?
3. Is the platform team spending less time on tickets?
4. Are we seeing fewer production incidents?
5. Are engineers satisfied with the experience?

**Every 6 Months, Review:**
1. Do tool boundaries still make sense?
2. Are we experiencing tool overlap or gaps?
3. Should we adjust what each tool manages?
4. Are there new tools or patterns to consider?

---

## Alternatives Considered (Detailed)

### Why Not Terraform for K8s Resources?

**Reasons Against:**
- Terraform's Kubernetes provider has a **poor developer experience** for frequent changes
- **State file** becomes a bottleneck for 50+ services deploying daily
- **Slow plan/apply cycles** (minutes) vs. K8s reconciliation (seconds)
- Doesn't leverage **K8s' orchestration capabilities** (health checks, rolling updates)
- Forces infrastructure mindset on application deployments

### Why Not Crossplane/Kubernetes Operators for AWS?

**Reasons Against:**
- **Maturity:** CRDs for AWS resources are still evolving
- **Circular Dependency:** Need K8s to create K8s (EKS cluster)
- **Complexity:** Requires deep operator knowledge
- **Debugging:** Harder to troubleshoot than Terraform
- **Multi-Cloud:** Less mature than Terraform for Azure/GCP
- **Team Expertise:** Platform team already proficient in Terraform

### Why Not Everything in Helm?

**Reasons Against:**
- Helm is **not designed for AWS resources** (RDS, IAM, VPCs)
- **Over-templating:** Simple deployments become complex charts
- **State Management:** Helm's state is weaker than Terraform
- **Release Management:** Unnecessary overhead for simple deploys
- Doesn't solve the AWS infrastructure problem

---

## References and Further Reading

### Internal References
- **ADR-001:** Terraform Cloud vs S3 for State Management
- **ADR-003:** Infrastructure Layering and Repository Structure
- **Platform Engineering Journey Map:** Internal developer workflow documentation
- **Service Catalog:** Atlassian Compass self-service requests

### External References

**Kubernetes:**
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [EKS Fargate Best Practices](https://docs.aws.amazon.com/eks/latest/userguide/fargate.html)

**Helm:**
- [Helm Documentation](https://helm.sh/docs/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Istio Helm Charts](https://istio.io/latest/docs/setup/install/helm/)

**Terraform:**
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Cloud Documentation](https://developer.hashicorp.com/terraform/cloud-docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

**Platform Engineering:**
- [Team Topologies](https://teamtopologies.com/) - Platform team patterns
- [CNCF Cloud Native Trail Map](https://github.com/cncf/trailmap) - Technology adoption sequence
- [Internal Developer Platforms](https://internaldeveloperplatform.org/) - IDP patterns

**Tool Comparisons:**
- [CNCF Landscape](https://landscape.cncf.io/) - Cloud native ecosystem
- [Terraform vs Crossplane](https://blog.upbound.io/crossplane-vs-terraform/)
- [When to Use Helm vs Kustomize](https://www.harness.io/blog/helm-vs-kustomize)

---

## Appendix A: Tool Capability Matrix

| Capability | Terraform | Helm | K8s Native | Winner | Why |
|-----------|-----------|------|------------|--------|-----|
| AWS Resource Management | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐ | Terraform | Designed for cloud APIs |
| K8s Resource Management | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | K8s Native | Native orchestration |
| Complex K8s Apps | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Helm | Package management |
| Change Velocity | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | K8s Native | Fast reconciliation |
| State Management | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | Terraform | Explicit state |
| Multi-Cloud | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ | Terraform | Provider ecosystem |
| Developer Experience | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | K8s Native | Designed for devs |
| GitOps Friendly | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | K8s Native | Declarative sync |
| Versioning & Rollback | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Helm | Semantic versioning |
| Policy Enforcement | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | Terraform | Sentinel policies |
| Drift Detection | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | Terraform | Plan command |
| Self-Healing | ⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | K8s Native | Built-in controllers |

**Legend:**
- ⭐⭐⭐⭐⭐ Excellent - Core strength of the tool
- ⭐⭐⭐⭐ Good - Well-supported, reliable
- ⭐⭐⭐ Adequate - Works but not optimal
- ⭐⭐ Poor - Possible but painful
- ⭐ Not Suitable - Wrong tool for the job

---

## Appendix B: Example Workflows

### Workflow 1: New Service Onboarding

```bash
# Step 1: Engineer runs scaffold CLI
$ platform-cli new-service --name payment-service --type api

Creating new service: payment-service
✓ Repository created: bitbucket.org/myorg/payment-service
✓ Kubernetes manifests generated
✓ BitBucket Pipeline configured
✓ ECR repository created (Terraform)
✓ Service registered in Compass

Next steps:
1. Clone repository: git clone git@bitbucket.org:myorg/payment-service.git
2. Write your code in /src
3. Push to trigger CI/CD: git push origin main

# Step 2: Engineer writes code and pushes
$ git add .
$ git commit -m "Initial payment service implementation"
$ git push origin main

# Step 3: BitBucket Pipeline runs automatically
[Pipeline] Building Docker image...
[Pipeline] Pushing to ECR...
[Pipeline] Deploying to dev cluster...
[Pipeline] ✓ Deployed successfully!

# Step 4: Service is live in dev environment
$ kubectl get pods -n dev
NAME                               READY   STATUS    RESTARTS   AGE
payment-service-7d4b9c8f6d-abcde   2/2     Running   0          30s
```

### Workflow 2: Requesting Database

```bash
# Step 1: Engineer creates request in Compass
[Compass UI] Create Request
  - Service: Payment Service
  - Resource Type: RDS Postgres
  - Size: db.t3.medium
  - Multi-AZ: Yes
  - Backup Retention: 7 days

# Step 2: Platform team reviews and approves

# Step 3: Platform team runs Terraform
$ cd terraform-infrastructure/03-shared-services/databases
$ terraform apply -var="service=payment-service"

# Step 4: Terraform creates RDS + Secret
resource "aws_db_instance" "payment_service" {
  identifier = "payment-service-prod"
  # ...
}

resource "aws_secretsmanager_secret" "payment_db_credentials" {
  name = "prod/payment-service/db-credentials"
}

# Step 5: Engineer consumes via External Secrets
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: db-credentials
  data:
  - secretKey: host
    remoteRef:
      key: prod/payment-service/db-credentials
      property: host
  - secretKey: password
    remoteRef:
      key: prod/payment-service/db-credentials
      property: password

# Step 6: Application uses K8s secret
env:
- name: DATABASE_HOST
  valueFrom:
    secretKeyRef:
      name: db-credentials
      key: host
```

### Workflow 3: Updating Istio Version

```bash
# Step 1: Platform team updates Helm chart version
$ cd helm-charts/istio
$ vim Chart.yaml  # Bump version to 1.21.0

# Step 2: Update values for new version if needed
$ vim values-production.yaml

# Step 3: Test in dev environment first
$ helm upgrade istio istio/istiod \
    -f values-dev.yaml \
    --namespace istio-system \
    --version 1.21.0

# Step 4: Validate in dev
$ kubectl -n istio-system get pods
$ kubectl -n dev exec -it test-pod -- curl -v payment-service

# Step 5: Deploy to production
$ helm upgrade istio istio/istiod \
    -f values-production.yaml \
    --namespace istio-system \
    --version 1.21.0

# Step 6: Monitor rollout
$ kubectl -n istio-system rollout status deployment/istiod

# Engineers' applications automatically use new Istio version
# No changes needed to application code or manifests
```

---

## Appendix C: Training Plan

### Training Track 1: Engineers (Application Developers)

**Duration:** 2 weeks (4 hours/week)

**Week 1: Kubernetes Fundamentals**
- Understanding K8s architecture (control plane, nodes, pods)
- Core resources: Deployments, Services, ConfigMaps, Secrets
- Kustomize for environment management
- Hands-on: Deploy sample application

**Week 2: Platform Services**
- Using Istio: VirtualServices, DestinationRules
- Writing Kyverno-compliant manifests
- External Secrets Operator
- Hands-on: Migrate existing service

**Post-Training:**
- Golden path documentation
- Office hours with Platform team
- Peer pairing for first deployment

### Training Track 2: Platform Team

**Duration:** 4 weeks (8 hours/week)

**Week 1: Helm Advanced**
- Chart development best practices
- Values schema validation
- Templating patterns
- Dependency management

**Week 2: Advanced Terraform**
- Module development
- Terraform Cloud workflows
- Sentinel policy writing
- Remote state patterns

**Week 3: Kubernetes Operators**
- External Secrets Operator configuration
- Kyverno policy development
- Custom admission controllers
- Operator SDK basics

**Week 4: Integration Patterns**
- Terraform → Helm handoffs
- Helm → K8s CRD usage
- Monitoring and observability
- Troubleshooting across layers

---

## Appendix D: FAQ

**Q: Why not use ArgoCD for GitOps?**  
A: ArgoCD is excellent and we may adopt it in Phase 4. Initially, BitBucket Pipelines + kubectl is simpler for teams to understand. ArgoCD adds value for more complex deployment patterns.

**Q: What about Terraform's Kubernetes provider?**  
A: We use it sparingly for EKS cluster creation and IAM roles for service accounts (IRSA). For application resources, native K8s manifests are superior.

**Q: Can engineers ever use Terraform directly?**  
A: Engineers can contribute Terraform modules via PR, but Platform team owns execution. This maintains governance and prevents state conflicts.

**Q: What if we need infrastructure that isn't templated?**  
A: Engineers can request via Compass. Platform team prioritizes common patterns to expand self-service catalog.

**Q: How do we handle secrets?**  
A: Secrets stored in AWS Secrets Manager (Terraform-managed). External Secrets Operator syncs to K8s Secrets. Engineers consume as normal K8s Secrets.

**Q: What about databases per service?**  
A: Currently shared RDS Postgres. Future: Terraform modules for dedicated RDS per service, or CRDs with AWS Controllers for Kubernetes (ACK).

**Q: How do we enforce resource limits?**  
A: Kyverno policies enforce CPU/memory limits. ResourceQuotas at namespace level. HorizontalPodAutoscalers for scaling.

**Q: What about local development?**  
A: Engineers use Docker Compose locally. K8s manifests apply in dev cluster. Future: Tilt for local K8s development.

**Q: How do we handle breaking changes?**  
A: Platform team announces changes in advance. Migration guides provided. Phased rollouts (dev → staging → prod). Rollback plans tested.

**Q: What if Helm chart updates break applications?**  
A: Test in dev first. Istio and Kyverno use non-breaking upgrades. If issues occur, Helm rollback available. Canary deployments for major changes.

---

## Decision Record Metadata

**Participants:**
- Platform Engineering Team
- Engineering Squad Leads
- DevOps Architects
- Cloud Infrastructure Team

**Review Date:** 2025-10-28  
**Next Review:** 2026-04-28 (6 months)

**Approval Required From:**
- [ ] VP Engineering
- [ ] Platform Engineering Lead
- [ ] Cloud Architect
- [ ] Security Team

**Supersedes:** None (New Decision)  
**Superseded By:** None (Active)

---

**Document Version:** 1.0  
**Last Updated:** 2025-10-28  
**Status:** Awaiting Approval