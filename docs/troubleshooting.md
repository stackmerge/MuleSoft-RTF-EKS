# Troubleshooting: MuleSoft Runtime Fabric on AWS EKS

## 1. AWS CLI authentication issues

### Symptom

```text
Unable to locate credentials
```

### Fix

Configure AWS CLI:

```bash
aws configure
```

Or for AWS SSO:

```bash
aws configure sso
aws sso login --profile your-profile-name
```

Validate identity:

```bash
aws sts get-caller-identity
```

## 2. kubectl is pointing to the wrong cluster

### Symptom

```text
The connection to the server localhost:8080 was refused
```

or commands are returning resources from a different cluster.

### Fix

Update kubeconfig:

```bash
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name mulesoft-eks-cluster
```

Check context:

```bash
kubectl config current-context
kubectl get nodes
```

## 3. EKS nodes are not Ready

### Symptom

```bash
kubectl get nodes
```

shows nodes as:

```text
NotReady
```

### Checks

```bash
kubectl get pods -n kube-system
kubectl describe node <node-name>
```

### Common causes

- AWS VPC CNI issue
- Node IAM role issue
- Subnet or security group issue
- Instance type capacity problem
- Cluster still initializing

### Fix

Wait a few minutes after cluster creation. If still failing, inspect node events:

```bash
kubectl describe node <node-name>
```

## 4. NGINX Ingress external IP is pending

### Symptom

```bash
kubectl get svc -n ingress-nginx
```

shows:

```text
EXTERNAL-IP: <pending>
```

### Fix

Wait 1-3 minutes and check again:

```bash
kubectl get svc -n ingress-nginx
```

If still pending, check service events:

```bash
kubectl describe svc ingress-nginx-controller -n ingress-nginx
```

Common causes:

- AWS Load Balancer quota exceeded
- Subnet tagging issue
- IAM permissions issue
- Cluster networking issue

## 5. rtfctl command not found

### Symptom

```text
zsh: command not found: rtfctl
```

### Fix

Install rtfctl:

```bash
curl -fsSL https://anypoint.mulesoft.com/runtimefabric/api/download/rtfctl-darwin/latest -o rtfctl
chmod +x rtfctl
sudo mv rtfctl /usr/local/bin/rtfctl
```

For Apple Silicon Homebrew path:

```bash
sudo mv rtfctl /opt/homebrew/bin/rtfctl
```

Validate:

```bash
which rtfctl
rtfctl -h
```

## 6. macOS blocks rtfctl execution

### Symptom

macOS security blocks the downloaded binary.

### Fix

```bash
xattr -d com.apple.quarantine /usr/local/bin/rtfctl
```

Or if installed under Homebrew path:

```bash
xattr -d com.apple.quarantine /opt/homebrew/bin/rtfctl
```

## 7. rtfctl validate fails

### Symptom

```bash
rtfctl validate "$RTF_ACTIVATION_DATA"
```

returns validation errors.

### Common causes

- Kubernetes context points to wrong cluster
- Nodes are not Ready
- Required Kubernetes permissions are missing
- Cluster version is unsupported
- Runtime Fabric entitlement or activation data issue
- Ingress controller not installed, if validation checks ingress prerequisites

### Checks

```bash
kubectl config current-context
kubectl get nodes
kubectl get pods -A
kubectl auth can-i '*' '*' --all-namespaces
```

### Fix

Resolve the validation issue shown by `rtfctl validate`. Do not run `rtfctl install` until validation succeeds.

## 8. Runtime Fabric pods are stuck in Pending

### Symptom

```bash
kubectl get pods -n rtf
```

shows pods in:

```text
Pending
```

### Checks

```bash
kubectl describe pod <pod-name> -n rtf
kubectl get events -n rtf --sort-by=.metadata.creationTimestamp
kubectl top nodes
```

### Common causes

- Insufficient CPU or memory
- Persistent volume issue
- Node taints
- Scheduling constraints
- Instance type too small

### Fix

For labs, use a larger node type if required:

```text
t3.large
m5.large
m5.xlarge
```

For production, follow MuleSoft sizing guidance.

## 9. Runtime Fabric status is not Active in Anypoint

### Symptom

Runtime Manager shows Runtime Fabric as:

```text
Disconnected
Installing
Error
Not Active
```

### Checks

```bash
kubectl get pods -n rtf
rtfctl status
kubectl logs -n rtf <pod-name>
```

### Common causes

- Runtime Fabric agent cannot reach Anypoint Platform
- Firewall/proxy restrictions
- DNS resolution issue
- Activation data problem
- Installation not completed

### Fix

Verify outbound internet connectivity from EKS worker nodes to Anypoint Platform endpoints. Check Runtime Fabric pod logs.

## 10. Mule license apply fails

### Symptom

```bash
rtfctl apply mule-license --file license.lic
```

fails.

### Checks

```bash
ls -la license.lic
rtfctl get mule-license
kubectl get pods -n rtf
```

### Common causes

- Invalid license file
- Expired license
- Wrong file path
- Runtime Fabric not fully installed

### Fix

Use the correct MuleSoft enterprise license file and rerun:

```bash
./scripts/apply-mule-license.sh ~/Downloads/license.lic
```

## 11. Mule app is deployed but endpoint is not reachable

### Checks

```bash
kubectl get ingress -A
kubectl get svc -A
kubectl get pods -n rtf
kubectl get svc -n ingress-nginx
```

Check DNS:

```bash
nslookup <your-app-hostname>
```

Check NGINX logs:

```bash
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### Common causes

- DNS not pointing to NGINX Load Balancer
- Ingress template not applied
- Wrong host name
- Wrong ingress class
- TLS certificate issue
- Mule app not healthy

## 12. AWS Load Balancer resources remain after teardown

### Symptom

EKS cluster is deleted but AWS Load Balancer still exists.

### Cause

Kubernetes `Service` type `LoadBalancer` or `Ingress` was not deleted before cluster deletion.

### Fix

Before deleting the cluster, always run:

```bash
kubectl get svc -A | grep LoadBalancer
kubectl get ingress -A
```

Then uninstall ingress:

```bash
helm uninstall ingress-nginx -n ingress-nginx
kubectl delete namespace ingress-nginx
```

After cluster deletion, verify in AWS Console:

```text
EC2 -> Load Balancers
EC2 -> Target Groups
CloudFormation -> Stacks
```

## 13. eksctl delete cluster fails

### Symptom

```bash
eksctl delete cluster --name mulesoft-eks-cluster --region ap-south-1 --wait
```

fails or hangs.

### Checks

```bash
eksctl get cluster --region ap-south-1
aws cloudformation list-stacks --region ap-south-1
```

### Fix

Check the CloudFormation stack events in AWS Console and remove blocking resources manually if necessary.
