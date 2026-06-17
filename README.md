# MuleSoft Runtime Fabric on AWS EKS

This repository provides a step-by-step guide to install **MuleSoft Runtime Fabric (RTF)** on an **Amazon Elastic Kubernetes Service (EKS)** cluster using a Mac workstation.

The guide covers:

- Installing required CLI tools on macOS
- Creating an EKS cluster with 3 worker nodes
- Installing an ingress controller
- Creating Runtime Fabric in Anypoint Platform
- Installing Runtime Fabric on EKS using `rtfctl`
- Applying Mule license
- Validating the setup
- Understanding NGINX Ingress vs AWS Load Balancer Controller
- Uninstalling Runtime Fabric and deleting the EKS cluster

---

## Table of Contents

1. [Use Case Overview](#use-case-overview)
2. [Target Architecture](#target-architecture)
3. [Prerequisites](#prerequisites)
4. [Install Required Tools on Mac](#install-required-tools-on-mac)
5. [Configure AWS Access](#configure-aws-access)
6. [Create EKS Cluster with 3 Nodes](#create-eks-cluster-with-3-nodes)
7. [Validate EKS Cluster](#validate-eks-cluster)
8. [Ingress Options for Runtime Fabric](#ingress-options-for-runtime-fabric)
9. [Install NGINX Ingress Controller](#install-nginx-ingress-controller)
10. [Create Runtime Fabric in Anypoint Platform](#create-runtime-fabric-in-anypoint-platform)
11. [Install Runtime Fabric on EKS](#install-runtime-fabric-on-eks)
12. [Apply Mule License](#apply-mule-license)
13. [Associate Runtime Fabric with Anypoint Environment](#associate-runtime-fabric-with-anypoint-environment)
14. [Configure Runtime Fabric Ingress Template](#configure-runtime-fabric-ingress-template)
15. [Generate and Apply Ingress Template Using Script](#generate-and-apply-ingress-template-using-script)
16. [Validation Checklist](#validation-checklist)
17. [Common Troubleshooting](#common-troubleshooting)
18. [Uninstall Runtime Fabric and Delete EKS Cluster](#uninstall-runtime-fabric-and-delete-eks-cluster)
19. [Production Hardening Recommendations](#production-hardening-recommendations)
20. [Repository Structure Recommendation](#repository-structure-recommendation)
21. [References](#references)

---

## Use Case Overview

The objective of this use case is to install **MuleSoft Runtime Fabric** on **AWS EKS** so Mule applications can be deployed and managed from **Anypoint Runtime Manager**, while the workloads run inside an AWS-managed Kubernetes cluster.

This setup is useful for:

- Learning Runtime Fabric on Kubernetes
- MuleSoft deployment practice on AWS EKS
- Runtime Fabric proof of concept
- Runtime Fabric architecture demos
- Preparing for production RTF deployment planning

---

## Target Architecture

```text
Developer Mac
   |
   | aws / eksctl / kubectl / helm / rtfctl
   v
Amazon EKS Cluster
   |
   +-- Managed Node Group: 3 Worker Nodes
   |
   +-- ingress-nginx namespace
   |      |
   |      +-- NGINX Ingress Controller
   |      +-- AWS LoadBalancer Service
   |
   +-- rtf namespace
          |
          +-- MuleSoft Runtime Fabric Components
          +-- Mule Application Pods
          +-- Runtime Fabric Agent
          +-- Runtime Fabric Services

Anypoint Platform
   |
   +-- Runtime Manager
   +-- Runtime Fabric Registration
   +-- Mule App Deployment Control Plane
```

Traffic flow for a simple NGINX-based setup:

```text
Client / Browser
   |
   v
AWS Load Balancer
   |
   v
NGINX Ingress Controller
   |
   v
Runtime Fabric Mule Application Service
   |
   v
Mule Application Pod
```

---

## Prerequisites

### Local Machine

- macOS
- Homebrew installed
- Internet access
- Terminal access

### AWS

You need AWS permissions to create and manage:

- EKS cluster
- EC2 worker nodes
- VPC and subnets
- Security groups
- IAM roles and policies
- Elastic Load Balancers
- CloudFormation stacks

### MuleSoft

You need:

- Anypoint Platform account
- Runtime Fabric entitlement
- Access to Runtime Manager
- Permission to create Runtime Fabric
- MuleSoft enterprise license file
- Ability to associate Runtime Fabric with an Anypoint environment

### Recommended AWS Region

This guide uses:

```bash
ap-south-1
```

You can replace it with your required AWS region.

---

## Install Required Tools on Mac

The following tools are required:

| Tool | Purpose |
|---|---|
| AWS CLI | Authenticate and manage AWS services |
| eksctl | Create and manage EKS clusters |
| kubectl | Interact with Kubernetes cluster |
| Helm | Install Kubernetes packages/charts |
| rtfctl | Install and manage MuleSoft Runtime Fabric |

---

### 1. Check Homebrew

```bash
brew --version
```

If Homebrew is not installed, install it:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

---

### 2. Install AWS CLI v2

```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

Verify:

```bash
aws --version
which aws
```

---

### 3. Install eksctl

```bash
brew tap aws/tap
brew install aws/tap/eksctl
```

Verify:

```bash
eksctl version
```

---

### 4. Install kubectl

```bash
brew install kubectl
```

Verify:

```bash
kubectl version --client
```

---

### 5. Install Helm

```bash
brew install helm
```

Verify:

```bash
helm version
which helm
```

---

### 6. Install rtfctl

```bash
curl -L https://anypoint.mulesoft.com/runtimefabric/api/download/rtfctl-darwin/latest -o rtfctl
chmod +x rtfctl
sudo mv rtfctl /usr/local/bin/rtfctl
```

Verify:

```bash
rtfctl -h
which rtfctl
```

For Apple Silicon Macs, if `/usr/local/bin` is not in your path, move `rtfctl` to Homebrew path:

```bash
sudo mv rtfctl /opt/homebrew/bin/rtfctl
```

If macOS blocks execution:

```bash
xattr -d com.apple.quarantine /usr/local/bin/rtfctl
```

---

## Configure AWS Access

### Option 1: Configure AWS CLI with Access Key

```bash
aws configure
```

Provide:

```text
AWS Access Key ID
AWS Secret Access Key
Default region name: ap-south-1
Default output format: json
```

Verify:

```bash
aws sts get-caller-identity
```

---

### Option 2: Configure AWS CLI with SSO

```bash
aws configure sso
aws sso login --profile your-profile-name
```

Verify:

```bash
aws sts get-caller-identity --profile your-profile-name
```

If you use a named profile, export it:

```bash
export AWS_PROFILE=your-profile-name
```

---

## Create EKS Cluster with 3 Nodes

Set variables:

```bash
export AWS_REGION=ap-south-1
export CLUSTER_NAME=mulesoft-eks-cluster
export NODEGROUP_NAME=standard-workers
```

Create the cluster:

```bash
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --nodegroup-name $NODEGROUP_NAME \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 3 \
  --nodes-max 3 \
  --managed
```

This command creates:

- EKS control plane
- Managed node group
- 3 EC2 worker nodes
- VPC
- Public/private subnets depending on `eksctl` defaults
- Route tables
- Security groups
- IAM roles
- Kubernetes kubeconfig entry on your Mac

> **Note:** `t3.medium` is suitable for learning or demo purposes only. For production Runtime Fabric workloads, use MuleSoft sizing guidance and AWS workload testing to select appropriate instance types.

---

## Validate EKS Cluster

Update kubeconfig:

```bash
aws eks update-kubeconfig \
  --region $AWS_REGION \
  --name $CLUSTER_NAME
```

Check current context:

```bash
kubectl config current-context
```

Check nodes:

```bash
kubectl get nodes -o wide
```

Expected result:

```text
3 nodes should be visible in Ready state
```

Check all pods:

```bash
kubectl get pods -A
```

---

## Ingress Options for Runtime Fabric

Runtime Fabric needs an ingress mechanism to expose Mule applications externally.

There are two common options on EKS:

| Option | Tool | Use Case |
|---|---|---|
| Option 1 | NGINX Ingress Controller | Simpler lab/demo setup |
| Option 2 | AWS Load Balancer Controller | AWS-native ALB/NLB-based setup |

---

### Option 1: NGINX Ingress Controller

This is the recommended option for a simple lab setup.

Traffic flow:

```text
Internet
   ↓
AWS Load Balancer
   ↓
NGINX Ingress Controller
   ↓
Runtime Fabric Mule App Service
   ↓
Mule App Pod
```

Use this when:

- You want a simple setup
- You are learning Runtime Fabric
- You want fewer AWS IAM prerequisites
- You do not need advanced ALB features

---

### Option 2: AWS Load Balancer Controller

This is used when you want AWS ALB/NLB to be managed directly by Kubernetes resources.

Traffic flow:

```text
Internet
   ↓
AWS ALB / NLB
   ↓
Runtime Fabric Mule App Service
   ↓
Mule App Pod
```

Use this when:

- You want AWS-native ingress
- You want ALB listener rules
- You want AWS WAF integration
- You want AWS ACM certificate integration
- You want production-grade AWS-native traffic management

AWS Load Balancer Controller requires additional IAM setup through IRSA/service account configuration.

---

### Do We Need Both?

No. For a basic Runtime Fabric setup on EKS, **one ingress strategy is sufficient**.

For this repository, the default approach is:

```text
NGINX Ingress Controller
```

Do not install both unless you are intentionally designing an advanced ingress architecture.

---

## Install NGINX Ingress Controller

Add Helm repository:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

Install NGINX ingress controller:

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.ingressClassResource.name=nginx \
  --set controller.ingressClass=nginx
```

Verify pods:

```bash
kubectl get pods -n ingress-nginx
```

Verify service:

```bash
kubectl get svc -n ingress-nginx
```

Wait until the service gets an external AWS Load Balancer DNS name:

```text
xxxx.elb.ap-south-1.amazonaws.com
```

Store the load balancer DNS name:

```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

---

## Create Runtime Fabric in Anypoint Platform

Go to Anypoint Platform:

```text
Anypoint Platform → Runtime Manager → Runtime Fabrics → Create Runtime Fabric
```

Use the following values:

```text
Runtime Fabric Name: mulesoft-eks-rtf
Target Platform: Amazon Elastic Kubernetes Service / Self-managed Kubernetes
Installation Method: rtfctl
```

Copy the **activation data** generated by Anypoint Platform.

Set it as an environment variable:

```bash
export ACTIVATION_DATA='<paste-activation-data-here>'
```

> **Security warning:** Do not commit activation data to GitHub. Treat it as a secret.

---

## Install Runtime Fabric on EKS

Validate Kubernetes cluster before installation:

```bash
rtfctl validate "$ACTIVATION_DATA"
```

Expected result:

```text
All validations successful. Proceed with installation.
```

Install Runtime Fabric:

```bash
rtfctl install "$ACTIVATION_DATA"
```

Check namespaces:

```bash
kubectl get ns
```

Check Runtime Fabric pods:

```bash
kubectl get pods -n rtf
```

Watch Runtime Fabric pods:

```bash
kubectl get pods -n rtf -w
```

Check Runtime Fabric status:

```bash
rtfctl status
```

Verify in Anypoint Platform:

```text
Runtime Manager → Runtime Fabrics → mulesoft-eks-rtf
```

Expected status:

```text
Active
```

---

## Apply Mule License

Place your Mule license file locally, for example:

```text
~/Downloads/license.lic
```

Apply license:

```bash
rtfctl apply mule-license --file ~/Downloads/license.lic
```

Verify license:

```bash
rtfctl get mule-license
```

> **Security warning:** Do not commit Mule license files to GitHub.

---

## Associate Runtime Fabric with Anypoint Environment

In Anypoint Platform:

```text
Runtime Manager
  → Runtime Fabrics
  → mulesoft-eks-rtf
  → Associated Environments
  → Add Environment
```

Select the required environment:

```text
Sandbox / Design / Production
```

Apply allocation.

Runtime Fabric must be associated with at least one Anypoint environment before Mule applications can be deployed to it.

---

## Configure Runtime Fabric Ingress Template

Runtime Fabric needs an ingress template so that Mule applications deployed to RTF can be exposed through the NGINX ingress controller.

This repository provides a ready-to-use manifest here:

```text
manifests/ingress-resource.yaml
```

The important value is:

```yaml
spec:
  ingressClassName: rtf-nginx
```

Important points:

- Runtime Fabric ingress templates use the `rtf-` prefix.
- For NGINX, use `rtf-nginx` in the Runtime Fabric template.
- The actual NGINX ingress controller uses `nginx` as the vendor-specific ingress class.
- The placeholder service name and service port must remain as `service-name` and `service-port`; Runtime Fabric replaces these values when Mule applications are deployed.

Apply the static manifest manually:

```bash
kubectl apply -f manifests/ingress-resource.yaml
```

Verify:

```bash
kubectl get ingress -n rtf
kubectl describe ingress rtf-nginx-ingress-template -n rtf
```

For real deployment, replace:

```text
rtf.example.com
```

with your real DNS domain.

Example DNS configuration:

```text
*.rtf.example.com → NGINX LoadBalancer DNS name
```

---

## Validation Checklist

Run the following commands:

```bash
kubectl get nodes
kubectl get pods -A
kubectl get pods -n rtf
kubectl get svc -n rtf
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
rtfctl status
rtfctl get mule-license
```

Expected status:

| Component | Expected Status |
|---|---|
| EKS nodes | Ready |
| ingress-nginx controller | Running |
| Runtime Fabric namespace | Present |
| Runtime Fabric pods | Running |
| Runtime Fabric in Anypoint | Active |
| Mule license | Applied |
| Environment association | Completed |
| LoadBalancer service | External DNS available |

---

## Common Troubleshooting

### 1. `kubectl get nodes` fails

Refresh kubeconfig:

```bash
aws eks update-kubeconfig \
  --region $AWS_REGION \
  --name $CLUSTER_NAME
```

Check context:

```bash
kubectl config current-context
```

---

### 2. EKS nodes are not Ready

Check nodes:

```bash
kubectl describe nodes
```

Check system pods:

```bash
kubectl get pods -n kube-system
```

Common causes:

- Insufficient IAM permissions
- Node group creation failed
- Networking issue
- VPC/subnet issue
- EC2 quota issue

---

### 3. `rtfctl validate` fails

Run:

```bash
rtfctl validate "$ACTIVATION_DATA"
```

Review the exact error.

Common causes:

- Wrong Kubernetes context
- Missing permissions
- Unsupported cluster configuration
- Resource constraints
- Network connectivity issue
- Activation data expired or copied incorrectly

---

### 4. NGINX LoadBalancer External IP is pending

Check service:

```bash
kubectl get svc -n ingress-nginx
```

Describe service:

```bash
kubectl describe svc ingress-nginx-controller -n ingress-nginx
```

Common causes:

- AWS cloud provider integration issue
- Subnet tagging issue
- IAM permission issue
- Load balancer quota issue

---

### 5. Runtime Fabric does not become Active in Anypoint Platform

Check pods:

```bash
kubectl get pods -n rtf
```

Check events:

```bash
kubectl get events -n rtf --sort-by='.lastTimestamp'
```

Check status:

```bash
rtfctl status
```

Common causes:

- Runtime Fabric pods not running
- Outbound connectivity blocked
- License not applied
- Activation data issue
- Cluster resource constraints

---

### 6. Mule license issue

Verify license:

```bash
rtfctl get mule-license
```

Reapply license:

```bash
rtfctl apply mule-license --file ~/Downloads/license.lic
```

---

### 7. AWS Load Balancer Controller command fails

If using AWS Load Balancer Controller instead of NGINX, ensure IAM service account exists before Helm installation:

```bash
kubectl get serviceaccount aws-load-balancer-controller -n kube-system
```

Your Helm command uses:

```bash
--set serviceAccount.create=false
--set serviceAccount.name=aws-load-balancer-controller
```

That means the service account must already exist and must be linked to the correct AWS IAM role.

---

## Uninstall Runtime Fabric and Delete EKS Cluster

Follow this order to avoid orphaned AWS resources and unnecessary billing.

---

### 1. Delete Mule Applications from Runtime Manager

In Anypoint Platform:

```text
Runtime Manager → Applications → Delete all apps deployed to this Runtime Fabric
```

Also delete API gateways if deployed to Runtime Fabric.

---

### 2. Delete Runtime Fabric from Anypoint Platform

In Anypoint Platform:

```text
Runtime Manager → Runtime Fabrics → Select mulesoft-eks-rtf → Delete Runtime Fabric
```

---

### 3. Uninstall Runtime Fabric from Kubernetes

```bash
rtfctl uninstall
```

Check namespace:

```bash
kubectl get all -n rtf
```

Delete namespace if still present and no longer needed:

```bash
kubectl delete namespace rtf
```

---

### 4. Delete NGINX Ingress Controller

```bash
helm uninstall ingress-nginx -n ingress-nginx
```

Delete namespace:

```bash
kubectl delete namespace ingress-nginx
```

Check remaining LoadBalancer services:

```bash
kubectl get svc -A | grep LoadBalancer
```

If any LoadBalancer service remains, delete it before deleting the EKS cluster.

---

### 5. Delete EKS Cluster

```bash
eksctl delete cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --wait
```

Verify deletion:

```bash
eksctl get cluster --region $AWS_REGION
```

Verify using AWS CLI:

```bash
aws eks describe-cluster \
  --region $AWS_REGION \
  --name $CLUSTER_NAME
```

Expected result after deletion:

```text
ResourceNotFoundException
```

---

### 6. Optional: Clean kubeconfig

List contexts:

```bash
kubectl config get-contexts
```

Delete old context:

```bash
kubectl config delete-context arn:aws:eks:ap-south-1:<account-id>:cluster/mulesoft-eks-cluster
```

Delete old cluster entry:

```bash
kubectl config delete-cluster arn:aws:eks:ap-south-1:<account-id>:cluster/mulesoft-eks-cluster
```

---

## Complete Command Summary

```bash
# Variables
export AWS_REGION=ap-south-1
export CLUSTER_NAME=mulesoft-eks-cluster
export NODEGROUP_NAME=standard-workers

# Create EKS cluster with 3 nodes
eksctl create cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --nodegroup-name $NODEGROUP_NAME \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 3 \
  --nodes-max 3 \
  --managed

# Connect kubectl to EKS
aws eks update-kubeconfig \
  --region $AWS_REGION \
  --name $CLUSTER_NAME

kubectl get nodes -o wide

# Install NGINX ingress controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.ingressClassResource.name=nginx \
  --set controller.ingressClass=nginx

kubectl get svc -n ingress-nginx

# Runtime Fabric installation
export ACTIVATION_DATA='<paste-activation-data-from-anypoint-platform>'

rtfctl validate "$ACTIVATION_DATA"
rtfctl install "$ACTIVATION_DATA"

kubectl get pods -n rtf
rtfctl status

# Generate and apply Runtime Fabric NGINX ingress template
export RTF_DOMAIN=rtf.muleaceacademy.com
./scripts/apply-rtf-nginx-ingress-template.sh

# Apply Mule license
rtfctl apply mule-license --file ~/Downloads/license.lic
rtfctl get mule-license

# Runtime Fabric uninstall
rtfctl uninstall
kubectl delete namespace rtf

# Delete ingress controller
helm uninstall ingress-nginx -n ingress-nginx
kubectl delete namespace ingress-nginx

# Delete EKS cluster
eksctl delete cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --wait
```

---

## Production Hardening Recommendations

For production Runtime Fabric on EKS, do not use this lab setup as-is. Consider the following improvements:

### AWS and EKS

- Use private subnets for worker nodes
- Use production-grade instance types
- Configure Cluster Autoscaler or Karpenter
- Use multiple Availability Zones
- Apply AWS resource tagging
- Configure IAM Roles for Service Accounts
- Restrict security group rules
- Use AWS CloudWatch Container Insights or another observability platform
- Configure backup and disaster recovery strategy
- Monitor EKS version lifecycle

### Runtime Fabric

- Follow MuleSoft sizing guidance
- Configure proper Runtime Fabric resource allocations
- Use dedicated node groups if required
- Configure environment-level deployment governance
- Apply Mule license securely
- Avoid committing Runtime Fabric activation data
- Avoid committing Mule license files

### Ingress and Security

- Use production DNS
- Use TLS certificates
- Consider AWS Load Balancer Controller for ALB/WAF/ACM integration
- Configure HTTPS-only endpoints
- Apply WAF rules where required
- Use network policies if supported in your CNI/networking design
- Review ingress controller lifecycle and support status before production rollout

### CI/CD

- Use GitHub Actions or another CI/CD tool to deploy Mule applications
- Store secrets in GitHub Secrets or a secure vault
- Separate configuration by environment
- Use Maven profiles for environment-specific deployments
- Add automated validation and smoke testing

---

## Repository Structure Recommendation

Recommended repository structure:

```text
.
├── README.md
├── scripts
│   ├── install-tools-mac.sh
│   ├── create-eks-cluster.sh
│   ├── install-nginx-ingress.sh
│   ├── install-runtime-fabric.sh
│   ├── apply-rtf-nginx-ingress-template.sh
│   ├── apply-mule-license.sh
│   └── uninstall-rtf-and-eks.sh
├── manifests
│   └── rtf-nginx-ingress-template.yaml
├── docs
│   ├── architecture.md
│   ├── troubleshooting.md
│   └── production-hardening.md
└── .gitignore
```

Recommended `.gitignore`:

```gitignore
# Secrets
.env
*.lic
activation-data.txt

# macOS
.DS_Store

# Logs
*.log

# Local kube config backups
kubeconfig*
```

---

## References

- MuleSoft Runtime Fabric Overview: https://docs.mulesoft.com/runtime-fabric/latest/
- MuleSoft Runtime Fabric Installation using rtfctl: https://docs.mulesoft.com/runtime-fabric/latest/install-self-managed
- MuleSoft rtfctl Installation: https://docs.mulesoft.com/runtime-fabric/latest/install-rtfctl
- MuleSoft Runtime Fabric Ingress Template Configuration: https://docs.mulesoft.com/runtime-fabric/latest/custom-ingress-configuration
- Amazon EKS Getting Started with eksctl: https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html
- AWS Load Balancer Controller: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
- AWS Load Balancer Controller Helm Installation: https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html
- Kubernetes kubectl Installation on macOS: https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/
- Helm Installation: https://helm.sh/docs/intro/install/
- ingress-nginx Helm Chart: https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx

---

## Disclaimer

This guide is intended for learning, proof of concept, and demo purposes. For production deployments, validate the architecture with MuleSoft and AWS best practices, security standards, sizing requirements, organizational governance, and operational readiness requirements.
