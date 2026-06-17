# Production Hardening Guide: MuleSoft Runtime Fabric on AWS EKS

## Purpose

This document lists recommended production-hardening considerations for running MuleSoft Runtime Fabric on Amazon EKS.

The scripts in this repository are optimized for a simple lab or proof-of-concept setup. Production deployments require additional security, reliability, scalability, governance, and operations design.

## 1. Cluster Sizing

Do not use the default lab node type for production without validation.

Lab default:

```text
Node type: t3.medium
Node count: 3
```

Production should consider:

- Number of Mule applications
- vCore allocation
- Expected request volume
- Payload size
- API latency expectations
- Batch workloads
- CPU/memory limits
- HA requirements
- Runtime Fabric overhead
- Logging and monitoring agents

Recommended production approach:

```text
1. Estimate workload capacity
2. Select larger instance family
3. Run load testing
4. Validate pod scheduling
5. Validate failover behavior
6. Tune autoscaling
```

## 2. Multi-AZ Design

Use worker nodes across multiple Availability Zones.

Recommended:

```text
Minimum 3 AZs where available
At least one worker node per AZ
Private subnets for worker nodes
Public subnets only for internet-facing load balancers
```

## 3. Private Networking

For production, prefer private worker nodes.

Recommended network pattern:

```text
Internet
  -> Public Load Balancer
  -> Private EKS worker nodes
  -> Runtime Fabric workloads
```

For internal APIs:

```text
Corporate Network / VPC
  -> Internal Load Balancer
  -> Private EKS worker nodes
  -> Runtime Fabric workloads
```

## 4. Ingress Strategy

This repository uses NGINX Ingress Controller for simplicity.

For production, evaluate both options.

### Option A: NGINX Ingress Controller

Good for:

- Kubernetes-native routing
- Central ingress proxy
- Flexible annotations
- Consistent routing across cloud providers

Production requirements:

- TLS configuration
- WAF or upstream protection
- Rate limiting if required
- NGINX resource requests/limits
- NGINX autoscaling
- Access logs
- Error logs
- Ingress controller monitoring

### Option B: AWS Load Balancer Controller

Good for:

- AWS-native ALB
- AWS WAF integration
- AWS ACM certificates
- ALB listener rules
- Native AWS observability

Production requirements:

- IAM role for service account
- OIDC provider for EKS
- ALB ingress class configuration
- Security group strategy
- WAF association
- ACM certificate management

## 5. DNS and TLS

Recommended:

```text
*.rtf.company.com -> ingress load balancer
```

Use TLS for all public endpoints.

Options:

- AWS ACM certificates with ALB
- cert-manager with NGINX
- Enterprise-managed certificate injection
- External DNS automation

Avoid plain HTTP for production APIs.

## 6. IAM and Access Control

Follow least privilege.

Recommended:

- Separate AWS IAM roles for cluster admins and operators
- Use AWS IAM Identity Center or federated access
- Avoid long-lived access keys
- Use IAM roles for service accounts where AWS controllers are used
- Restrict who can update kubeconfig
- Restrict who can run `rtfctl uninstall`
- Restrict who can delete EKS clusters

## 7. Kubernetes RBAC

Create role-based access for:

```text
Cluster administrators
Platform operators
Read-only support users
CI/CD service accounts
Monitoring service accounts
```

Avoid using cluster-admin for day-to-day operations.

## 8. Secrets Management

Do not commit secrets to GitHub.

Never commit:

- Runtime Fabric activation data
- Mule license file
- AWS access keys
- Anypoint credentials
- TLS private keys
- API client secrets

Recommended options:

- AWS Secrets Manager
- External Secrets Operator
- Sealed Secrets
- CI/CD secret store
- Anypoint secure properties for application secrets

## 9. Runtime Fabric Activation Data

Runtime Fabric activation data should be treated as sensitive.

Recommended:

```text
Store temporarily during installation only
Do not persist in Git history
Do not print in logs
Rotate/recreate Runtime Fabric if leaked
```

## 10. Logging and Monitoring

Recommended observability stack:

- Amazon CloudWatch Container Insights
- Prometheus/Grafana
- Fluent Bit or OpenTelemetry collector
- Runtime Fabric metrics
- Mule application logs
- Kubernetes events
- Ingress access logs
- AWS Load Balancer logs

Monitor:

```text
Node CPU/memory
Pod CPU/memory
Pod restarts
Runtime Fabric agent health
Mule application health
Ingress latency
HTTP 4xx/5xx
Load balancer target health
Persistent volume usage
Kubernetes events
```

## 11. Alerting

Recommended alerts:

```text
Node NotReady
Pod CrashLoopBackOff
Runtime Fabric disconnected
Mule app unavailable
Ingress 5xx spike
High CPU/memory
Disk pressure
Load balancer target unhealthy
Certificate expiry
Deployment failure
```

## 12. Autoscaling

Evaluate:

- Cluster Autoscaler or Karpenter for node scaling
- Horizontal Pod Autoscaler where supported and appropriate
- NGINX Ingress Controller autoscaling
- Separate node groups for different workload classes

Do not enable aggressive autoscaling without testing application startup time and traffic behavior.

## 13. Resource Requests and Limits

Production workloads should define resource requests and limits.

Validate:

```text
CPU request
CPU limit
Memory request
Memory limit
Replica count
Pod disruption budget
Node capacity
```

## 14. High Availability

Recommended:

- Multi-AZ node groups
- Multiple replicas for critical components
- Pod anti-affinity where required
- Pod disruption budgets
- Rolling deployment validation
- Backup/restore plan

## 15. Upgrade Strategy

Plan upgrades for:

```text
EKS Kubernetes version
Managed node group AMI
Runtime Fabric version
Mule runtime version
NGINX Ingress Controller
Helm charts
kubectl client
rtfctl binary
```

Recommended process:

```text
1. Test upgrade in non-prod
2. Validate Mule app deployments
3. Validate ingress
4. Run smoke tests
5. Run performance tests
6. Upgrade production during approved window
```

## 16. Backup and Recovery

Define recovery process for:

- EKS cluster rebuild
- Runtime Fabric reinstall
- Mule app redeployment
- DNS re-pointing
- Secrets restoration
- Configuration restoration
- License reapply

Keep infrastructure and platform setup codified where possible.

## 17. CI/CD Integration

Recommended:

```text
Source code in GitHub
Build/test using GitHub Actions or enterprise CI/CD
Deploy Mule apps using Maven or Anypoint APIs
Use environment-specific properties
Use approval gates for production
Use release tags
Use rollback procedures
```

## 18. Security Controls

Recommended controls:

- Private EKS endpoint where possible
- Restricted Kubernetes API access
- Network policies
- AWS Security Groups
- Pod security standards
- Image scanning
- Container runtime hardening
- Secrets encryption
- TLS everywhere
- WAF for public APIs
- Audit logging

## 19. Cost Controls

Production EKS creates ongoing AWS charges.

Monitor:

```text
EKS control plane cost
EC2 worker node cost
Load balancer cost
NAT gateway cost
CloudWatch logs cost
Data transfer cost
EBS volume cost
```

Recommended:

- Tag all resources
- Use AWS Budgets
- Use cost allocation tags
- Delete unused load balancers
- Right-size nodes
- Review log retention

## 20. Production Readiness Checklist

Before production go-live, confirm:

```text
[ ] EKS cluster is multi-AZ
[ ] Worker nodes are private
[ ] Ingress is TLS-enabled
[ ] DNS is configured
[ ] Runtime Fabric is Active
[ ] Mule license is applied
[ ] Environment is associated
[ ] Monitoring is enabled
[ ] Alerts are configured
[ ] Logs are centralized
[ ] IAM is least privilege
[ ] Secrets are externalized
[ ] Backup/recovery is documented
[ ] Load testing is completed
[ ] Failover testing is completed
[ ] Upgrade process is documented
[ ] Teardown protection is in place
```
