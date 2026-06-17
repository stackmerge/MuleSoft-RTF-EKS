# Architecture: MuleSoft Runtime Fabric on AWS EKS

## Overview

This use case deploys **MuleSoft Runtime Fabric** on **Amazon Elastic Kubernetes Service** using a 3-node managed EKS cluster. Runtime Fabric provides the MuleSoft-managed runtime layer for deploying Mule applications on customer-managed Kubernetes infrastructure.

The setup uses:

- AWS EKS as the Kubernetes platform
- Managed EKS node group with 3 EC2 worker nodes
- NGINX Ingress Controller for external HTTP/HTTPS routing
- Runtime Fabric installed through `rtfctl`
- Mule license applied using `rtfctl`
- Anypoint Runtime Manager for Runtime Fabric registration, management, and deployment visibility

## Logical Architecture

```text
Developer/Admin Mac
  ├── aws cli
  ├── eksctl
  ├── kubectl
  ├── helm
  └── rtfctl
        |
        | kubeconfig
        v
AWS EKS Cluster
  |
  ├── kube-system namespace
  |     ├── CoreDNS
  |     ├── kube-proxy
  |     └── AWS VPC CNI
  |
  ├── ingress-nginx namespace
  |     └── NGINX Ingress Controller
  |           |
  |           v
  |        AWS Load Balancer
  |
  └── rtf namespace
        ├── Runtime Fabric agent components
        ├── Mule runtime components
        ├── Runtime Fabric services
        └── Mule application workloads
```

## Runtime Flow

```text
Client / Consumer
   |
   v
DNS Record
   |
   v
AWS Load Balancer created for NGINX Ingress Controller
   |
   v
NGINX Ingress Controller
   |
   v
Runtime Fabric ingress rule
   |
   v
Mule Application service
   |
   v
Mule Application pod
```

## Why NGINX Ingress Controller?

This repository uses **NGINX Ingress Controller** as the default ingress strategy because it is simple for labs, demos, and first-time Runtime Fabric setup.

NGINX Ingress Controller provides:

- Host-based routing
- Path-based routing
- TLS termination support
- One central ingress controller for multiple Mule applications
- Simple Kubernetes-native troubleshooting

## NGINX Ingress vs AWS Load Balancer Controller

There are two common ingress approaches on EKS.

### Option 1: NGINX Ingress Controller

Used by this repository.

```text
Internet
  -> AWS Load Balancer
  -> NGINX Ingress Controller
  -> Mule app service
  -> Mule app pod
```

Best for:

- Lab setup
- Demo setup
- First Runtime Fabric installation
- Simpler troubleshooting
- Reducing AWS IAM setup complexity

### Option 2: AWS Load Balancer Controller

AWS-native approach.

```text
Internet
  -> AWS ALB
  -> Mule app service
  -> Mule app pod
```

Best for:

- Production AWS-native ingress
- AWS WAF integration
- AWS ACM certificate integration
- ALB listener rules
- Advanced AWS routing requirements

This repository does **not** install AWS Load Balancer Controller by default.

## Main Components

### 1. AWS EKS Cluster

The EKS cluster hosts Runtime Fabric and Mule application workloads. The provided script creates:

- EKS control plane
- Managed node group
- 3 worker nodes
- VPC and subnets, unless existing VPC configuration is added later
- IAM roles and security groups created by `eksctl`

### 2. Managed Node Group

Default configuration:

```text
Node type: t3.medium
Desired nodes: 3
Minimum nodes: 3
Maximum nodes: 3
```

For production, use MuleSoft sizing guidance and workload-specific capacity planning. Do not assume `t3.medium` is sufficient for production workloads.

### 3. Runtime Fabric Namespace

Runtime Fabric components are installed into the `rtf` namespace.

Common validation commands:

```bash
kubectl get pods -n rtf
kubectl get svc -n rtf
rtfctl status
```

### 4. Ingress Namespace

NGINX Ingress Controller is installed into the `ingress-nginx` namespace.

Common validation commands:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### 5. Runtime Fabric Ingress Template

The template file is located at:

```text
manifests/rtf-nginx-ingress-template.yaml
```

It uses:

```yaml
spec:
  ingressClassName: rtf-nginx
```

Runtime Fabric uses the `rtf-` prefix for custom ingress templates.

## DNS Strategy

For a real deployment, configure DNS like this:

```text
*.rtf.example.com -> NGINX Load Balancer DNS name
```

Example Mule app URL:

```text
https://orders-api.rtf.example.com
```

## Recommended Deployment Sequence

```text
1. Install local tools
2. Create EKS cluster
3. Install NGINX Ingress Controller
4. Create Runtime Fabric in Anypoint Runtime Manager
5. Copy activation data
6. Run rtfctl validate
7. Run rtfctl install
8. Apply Mule license
9. Associate Runtime Fabric with Anypoint environment
10. Apply ingress template
11. Deploy Mule application
12. Validate external endpoint
```

## Recommended Teardown Sequence

```text
1. Delete Mule apps from Runtime Manager
2. Delete API gateways from Runtime Manager, if any
3. Delete Runtime Fabric from Runtime Manager
4. Run rtfctl uninstall
5. Delete rtf namespace
6. Delete NGINX ingress controller
7. Delete ingress-nginx namespace
8. Delete EKS cluster
9. Verify AWS Load Balancers are removed
```
