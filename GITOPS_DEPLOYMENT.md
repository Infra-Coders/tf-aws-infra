# GitOps Deployment Guide - Complete Procedure

Complete step-by-step guide for deploying Kubernetes infrastructure using GitOps methodology with Flux CD.

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Phase 1: Infrastructure Bootstrap](#phase-1-infrastructure-bootstrap)
- [Phase 2: Install Flux CD](#phase-2-install-flux-cd)
- [Phase 3: Verify GitOps Deployment](#phase-3-verify-gitops-deployment)
- [Phase 4: Deploy Applications](#phase-4-deploy-applications)
- [Managing Your GitOps Setup](#managing-your-gitops-setup)
- [Troubleshooting](#troubleshooting)
- [Cleanup and Destroy](#cleanup-and-destroy)
- [Migration from Scripts](#migration-from-scripts)

---

## Overview

### What is GitOps?

GitOps is a declarative approach where:
- **Git is the single source of truth** for all infrastructure and applications
- **Automated reconciliation** ensures cluster state matches Git repository
- **Changes are made via Git commits**, not manual kubectl/helm commands
- **Flux CD automatically detects drift** and corrects it every 2 minutes

### What This Guide Covers

This guide replaces the manual script-based deployment approach with automated GitOps:

**Old Approach (Scripts):**
```bash
./scripts/deploy-aws-cloud-provider.sh
./scripts/deploy-external-dns.sh
./scripts/deploy-ingress-nginx.sh
```

**New Approach (GitOps):**
```bash
podman_flux bootstrap github ...
# Flux automatically deploys everything from Git
```

---

## Architecture

### Repository Structure

```
tf-aws-infra/              # This repository - Infrastructure provisioning
├── single-master-k8s/     # Terraform + Kubernetes bootstrap
└── ic-utils/              # Containerized tooling (podman_*)

ic-gitops-central/         # GitOps orchestrator (Flux entry point)
├── clusters/
│   └── dev/
│       ├── base/          # Shared base configuration
│       │   ├── aws.yaml   # Points to ic-aws-stack
│       │   └── ingress.yaml # Points to ic-ingress-stack
│       ├── luke/          # User "luke" specific config
│       │   ├── aws.yaml
│       │   └── ingress.yaml
│       └── moose/         # User "moose" specific config

ic-aws-stack/              # AWS components (separate repo)
├── clusters/
│   ├── base/
│   │   ├── aws-cloud-controller-manager.yaml  # HelmRelease
│   │   ├── external-dns.yaml                  # HelmRelease
│   │   └── helm/repository.yaml               # HelmRepository
│   └── dev/
│       └── luke/
│           ├── kustomization.yaml
│           └── external-dns-patch.yaml        # Domain-specific config

ic-ingress-stack/          # Ingress controller (separate repo)
├── clusters/
│   ├── base/
│   │   ├── namespace.yaml
│   │   ├── helmrelease.yaml                   # NGINX Ingress
│   │   └── helm/repository.yaml
│   └── dev/
│       ├── kustomization.yaml
│       └── patch.yaml                         # Environment-specific config
```

### Component Flow

```
1. You bootstrap Flux → points to ic-gitops-central/clusters/dev/luke
2. Flux reads GitRepository resources (aws.yaml, ingress.yaml)
3. Flux clones ic-aws-stack and ic-ingress-stack repositories
4. Flux applies Kustomization (base + user/environment patches)
5. Helm Controller deploys HelmReleases
6. Flux reconciles every 2 minutes (auto-detects and fixes drift)
```

### What Gets Deployed Automatically

**From ic-aws-stack:**
- AWS Cloud Controller Manager (enables LoadBalancer services)
- External DNS (automatic Route53 DNS record management)

**From ic-ingress-stack:**
- NGINX Ingress Controller (HTTP/HTTPS routing with single NLB)

---

## Prerequisites

### 1. Build Containerized Runtime

The `ic-podman-runtime` container includes all necessary tools (kubectl, helm, terraform, flux).

```bash
cd tf-aws-infra/ic-utils/podman/ic-runtime

# Check your architecture
uname -m
# x86_64 = amd64, arm64 = arm64

# Build for AMD64
podman build --platform linux/amd64 -t ic-podman-runtime -f ./Containerfile.amd64 .

# OR build for ARM64
podman build --platform linux/arm64 -t ic-podman-runtime -f ./Containerfile.arm64 .
```

**Verify the build:**
```bash
podman images | grep ic-podman-runtime
```

### 2. Setup Utility Wrappers

```bash
cd /Users/luke/Library/CloudStorage/OneDrive-Osobisty/Luke/Firma_IT/tf-aws-infra/ic-utils
./setup_WORKDIR
```

This creates symlinks in `~/bin/` for:
- `podman_kubectl` - Kubernetes CLI
- `podman_helm` - Helm package manager
- `podman_terraform` - Infrastructure provisioning
- `podman_flux` - GitOps CLI (new!)
- `podman_run` - Generic container runner

**Verify installation:**
```bash
which podman_flux
podman_flux --version
```

### 3. AWS Credentials

```bash
aws configure --profile <your_profile>
# AWS Access Key ID: ****************
# AWS Secret Access Key: ****************
# Default region: eu-central-1
# Default output format: json
```

### 4. GitHub Personal Access Token

Flux needs GitHub access to read/write repositories.

1. Go to: https://github.com/settings/tokens
2. Generate new token (classic)
3. Select scopes: `repo` (full control of private repositories)
4. Save the token securely

**Export the token:**
```bash
export GITHUB_TOKEN=ghp_your_token_here
```

---

## Phase 1: Infrastructure Bootstrap

Deploy the base Kubernetes cluster using Terraform and kubeadm.

### Step 1.1: Deploy AWS Infrastructure

```bash
cd tf-aws-infra/single-master-k8s

# Initialize Terraform
podman_terraform init

# Review planned changes
podman_terraform plan

# Deploy infrastructure (VPC, EC2 instances, IAM roles, etc.)
podman_terraform apply
```

**What gets created:**
- VPC with public/private subnets
- 1 master node + 3 worker nodes (EC2 instances)
- Security groups, IAM roles, instance profiles
- Route tables, internet gateway

### Step 1.2: Bootstrap Kubernetes Cluster

```bash
# Bootstrap Kubernetes with kubeadm + Calico CNI
podman_run ./scripts/BOOTSTRAP_KUBE.sh
```

**What this does:**
- Installs Kubernetes v1.32.10 via kubeadm
- Configures Calico CNI with eBPF dataplane
- Sets up CRI-O container runtime
- Patches CoreDNS to use Google DNS (8.8.8.8)
- Automatically sets ProviderID on all nodes

### Step 1.3: Verify Cluster

```bash
# Set kubeconfig
export KUBECONFIG=~/.kube/aws-k8s

# Check nodes
podman_kubectl get nodes -o wide

# Verify ProviderID is set (required for AWS Cloud Controller)
podman_kubectl get nodes -o custom-columns=NAME:.metadata.name,PROVIDER-ID:.spec.providerID

# Check system pods
podman_kubectl get pods -A
```

**Expected output:**
- All nodes: `Ready`
- All pods: `Running`
- ProviderID format: `aws:///eu-central-1a/i-xxxxx`

---

## Phase 2: Install Flux CD

Bootstrap Flux CD to enable GitOps automation.

### Step 2.1: Verify Prerequisites

```bash
export KUBECONFIG=~/.kube/aws-k8s

# Check Flux prerequisites
podman_flux check --pre
```

**Expected output:**
```
✔ Kubernetes 1.32.10 >=1.28.0-0
✔ prerequisites checks passed
```

### Step 2.2: Bootstrap Flux to GitHub

**Important:** Replace `luke` with your username in the path.

```bash
# Ensure GitHub token is set
echo $GITHUB_TOKEN

# Bootstrap Flux
podman_flux bootstrap github \
  --owner=Infra-Coders \
  --repository=ic-gitops-central \
  --branch=main \
  --path=clusters/dev/luke \
  --token-auth
```

**What this does:**
1. Installs Flux controllers in `flux-system` namespace
2. Creates/updates `ic-gitops-central` repository with Flux manifests
3. Configures Flux to watch `clusters/dev/luke` path
4. Flux starts automatic reconciliation every 2 minutes

**Expected output:**
```
✔ source-controller: deployment ready
✔ kustomize-controller: deployment ready
✔ helm-controller: deployment ready
✔ notification-controller: deployment ready
✔ all components are healthy
```

### Step 2.3: Verify Flux Installation

```bash
# Check Flux pods
podman_kubectl get pods -n flux-system

# Expected: 4 pods running
# - source-controller
# - kustomize-controller
# - helm-controller
# - notification-controller

# Check Flux resources
podman_flux get all
```

---

## Phase 3: Verify GitOps Deployment

Flux automatically deploys components based on your Git configuration.

### Step 3.1: Monitor Flux Reconciliation

```bash
# Watch Flux logs in real-time
podman_flux logs --follow

# In another terminal, watch resources
watch podman_kubectl get pods -A
```

### Step 3.2: Check GitRepository Sources

```bash
# List Git repositories Flux is watching
podman_flux get sources git

# Expected output:
# NAME            REVISION        SUSPENDED  READY
# flux-system     main@sha1:xxx   False      True
# ic-aws-stack    v0.0.1@sha1:xxx False      True
# ic-ingress-stack v0.0.1@sha1:xxx False      True
```

### Step 3.3: Check Kustomizations

```bash
# List Kustomizations (applied manifests)
podman_flux get kustomizations

# Expected output:
# NAME         REVISION        SUSPENDED  READY
# flux-system  main@sha1:xxx   False      True
# ic-aws       v0.0.1@sha1:xxx False      True
# ic-ingress   v0.0.1@sha1:xxx False      True
```

### Step 3.4: Check HelmReleases

```bash
# List Helm releases deployed by Flux
podman_flux get helmreleases -A

# Expected output:
# NAMESPACE      NAME                          REVISION  SUSPENDED  READY
# kube-system    aws-cloud-controller-manager  0.0.x     False      True
# kube-system    external-dns                  1.14.4    False      True
# ingress-nginx  ingress-nginx                 4.10.0    False      True
```

### Step 3.5: Verify Component Pods

```bash
# AWS Cloud Controller Manager
podman_kubectl get pods -n kube-system -l k8s-app=aws-cloud-controller-manager

# External DNS
podman_kubectl get pods -n kube-system -l app.kubernetes.io/name=external-dns

# NGINX Ingress Controller
podman_kubectl get pods -n ingress-nginx

# All should show STATUS: Running
```

### Step 3.6: Get LoadBalancer Hostname

```bash
# Get NLB hostname (takes 2-3 minutes to provision)
podman_kubectl get svc ingress-nginx-controller -n ingress-nginx

# Expected output:
# NAME                       TYPE           EXTERNAL-IP
# ingress-nginx-controller   LoadBalancer   a1234567890abcdef-123456789.eu-central-1.elb.amazonaws.com
```

**Save this hostname** - you'll need it for DNS configuration and testing.

---

## Phase 4: Deploy Applications

Now that GitOps is active, deploy applications using Ingress resources.

### Step 4.1: Deploy Example Application

```bash
# Deploy example app with Ingress
podman_kubectl apply -f manifests/example-app.yaml

# Check deployment
podman_kubectl get pods
podman_kubectl get ingress
```

### Step 4.2: Test Ingress Routing

```bash
# Get NLB hostname
NLB_HOSTNAME=$(podman_kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test with Host header
curl -H "Host: demo.luke.infra-coders.com" http://$NLB_HOSTNAME

# Expected: Response from your application
```

### Step 4.3: Verify External DNS (if configured)

```bash
# Check external-dns logs
podman_kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns --tail=50

# Look for messages like:
# "CREATE demo.luke.infra-coders.com A [NLB-IP]"

# Verify DNS record
dig demo.luke.infra-coders.com +short
# Should return NLB IP address
```

### Step 4.4: Deploy Your Own Application

Create three resources:

**1. Deployment** (`myapp-deployment.yaml`):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        ports:
        - containerPort: 8080
```

**2. Service** (`myapp-service.yaml`):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
```

**3. Ingress** (`myapp-ingress.yaml`):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
    external-dns.alpha.kubernetes.io/hostname: "myapp.luke.infra-coders.com"
spec:
  rules:
  - host: myapp.luke.infra-coders.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

**Deploy:**
```bash
podman_kubectl apply -f myapp-deployment.yaml
podman_kubectl apply -f myapp-service.yaml
podman_kubectl apply -f myapp-ingress.yaml

# Verify
podman_kubectl get pods
podman_kubectl get ingress
```

---

## Managing Your GitOps Setup

### Updating Component Versions

To update a component version, edit the GitRepository tag in `ic-gitops-central`:

```bash
cd /path/to/ic-gitops-central

# Edit clusters/dev/luke/aws.yaml
# Change: tag: v0.0.1 → tag: v0.0.2

git add clusters/dev/luke/aws.yaml
git commit -m "Update aws-stack to v0.0.2"
git push

# Flux detects change within 2 minutes
# Or force immediate reconciliation:
podman_flux reconcile kustomization flux-system --with-source
```

### Changing Configuration

To modify component configuration, edit patches in the component repository:

```bash
cd /path/to/ic-aws-stack

# Edit clusters/dev/luke/external-dns-patch.yaml
# Add another domain filter

git add clusters/dev/luke/external-dns-patch.yaml
git commit -m "Add additional domain filter"
git push

# Force reconciliation
podman_flux reconcile kustomization ic-aws --with-source
```

### Suspending Reconciliation

To temporarily stop Flux from reconciling:

```bash
# Suspend a specific Kustomization
podman_flux suspend kustomization ic-aws

# Resume
podman_flux resume kustomization ic-aws
```

### Manual Reconciliation

Force Flux to reconcile immediately:

```bash
# Reconcile specific Kustomization
podman_flux reconcile kustomization ic-aws --with-source

# Reconcile HelmRelease
podman_flux reconcile helmrelease external-dns -n kube-system
```

---

## Troubleshooting

### Flux Not Reconciling

```bash
# Check Flux controller status
podman_kubectl get pods -n flux-system

# Check Flux logs
podman_flux logs --level=error

# Check specific controller
podman_kubectl logs -n flux-system -l app=source-controller
podman_kubectl logs -n flux-system -l app=kustomize-controller
podman_kubectl logs -n flux-system -l app=helm-controller
```

### GitRepository Not Ready

```bash
# Check GitRepository status
podman_flux get sources git

# Describe for detailed errors
podman_kubectl describe gitrepository ic-aws-stack -n flux-system

# Common issues:
# - Invalid Git URL
# - Missing authentication
# - Tag/branch doesn't exist
```

### Kustomization Failed

```bash
# Check Kustomization status
podman_flux get kustomizations

# Describe for errors
podman_kubectl describe kustomization ic-aws -n flux-system

# Common issues:
# - Invalid YAML syntax
# - Missing resources
# - Kustomize build errors
```

### HelmRelease Failed

```bash
# Check HelmRelease status
podman_flux get helmreleases -A

# Describe for errors
podman_kubectl describe helmrelease aws-cloud-controller-manager -n kube-system

# Check Helm release history
podman_helm list -A

# Common issues:
# - Invalid values
# - Chart version not found
# - Resource conflicts
```

### Component Pods Not Running

```bash
# Check pod status
podman_kubectl get pods -A

# Describe pod for events
podman_kubectl describe pod <pod-name> -n <namespace>

# Check logs
podman_kubectl logs <pod-name> -n <namespace>

# Common issues:
# - Image pull errors
# - Resource constraints
# - Configuration errors
# - IAM permission issues (for AWS components)
```

### LoadBalancer Not Provisioning

```bash
# Check service
podman_kubectl get svc ingress-nginx-controller -n ingress-nginx

# Check AWS Cloud Controller logs
podman_kubectl logs -n kube-system -l k8s-app=aws-cloud-controller-manager

# Verify IAM permissions
aws iam get-role --role-name <cluster-role-name>

# Common issues:
# - Missing IAM permissions
# - AWS Cloud Controller not running
# - VPC/subnet configuration issues
```

### External DNS Not Creating Records

```bash
# Check external-dns logs
podman_kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns --tail=100

# Verify Route53 hosted zone
aws route53 list-hosted-zones

# Check IAM permissions
aws iam get-role-policy --role-name <cluster-role-name> --policy-name ExternalDNSPolicy

# Common issues:
# - Wrong hosted zone ID
# - Missing IAM permissions
# - Domain filter mismatch
# - Ingress missing annotation
```

### Flux Bootstrap Fails: "push declined due to repository rule violations"

**Error:**
```
✗ failed to push manifests: failed to push to remote: command error on refs/heads/main:
push declined due to repository rule violations
```

**Cause:** GitHub repository has branch protection rules that prevent Flux from pushing commits.

**Solution 1: Disable Branch Protection (Temporary)**

1. Go to GitHub repository settings: `https://github.com/Infra-Coders/ic-gitops-central/settings/rules`
2. Find the rule protecting `main` branch
3. Temporarily disable or delete the rule
4. Re-run Flux bootstrap:
   ```bash
   podman_flux bootstrap github \
     --owner=Infra-Coders \
     --repository=ic-gitops-central \
     --branch=main \
     --path=clusters/dev/luke \
     --token-auth
   ```
5. Re-enable branch protection after bootstrap completes

**Solution 2: Use Different Branch**

Bootstrap Flux to a different branch without protection:

```bash
podman_flux bootstrap github \
  --owner=Infra-Coders \
  --repository=ic-gitops-central \
  --branch=flux-system \
  --path=clusters/dev/luke \
  --token-auth
```

**Solution 3: Bypass Rules (if you have admin access)**

Add your GitHub token to the bypass list in repository settings, then bootstrap.

**Solution 4: Manual Installation (Advanced)**

If bootstrap continues to fail, install Flux manually:

```bash
# Install Flux components
podman_flux install

# Create GitRepository pointing to ic-gitops-central
cat <<EOF | podman_kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m
  ref:
    branch: main
  url: https://github.com/Infra-Coders/ic-gitops-central
EOF

# Create Kustomization
cat <<EOF | podman_kubectl apply -f -
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/dev/luke
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
EOF
```

---

## Cleanup and Destroy

### Important: Cleanup Order

Always remove Kubernetes resources before destroying Terraform infrastructure to avoid orphaned AWS resources (LoadBalancers, security groups, etc.).

### Step 1: Uninstall Flux CD

```bash
export KUBECONFIG=~/.kube/aws-k8s

# Uninstall Flux (this removes all GitOps-managed resources)
podman_flux uninstall --silent

# Verify Flux is removed
podman_kubectl get pods -n flux-system
# Should show: No resources found
```

**Note:** Flux uninstall will remove all components it deployed (AWS Cloud Controller, External DNS, Ingress NGINX).

### Step 2: Remove Any Remaining LoadBalancer Services

```bash
# List all LoadBalancer services
podman_kubectl get svc --all-namespaces -o wide | grep LoadBalancer

# Delete each LoadBalancer service if any remain
podman_kubectl delete svc <service-name> -n <namespace>

# Wait for AWS to clean up LoadBalancers
sleep 180
```

### Step 3: Verify No LoadBalancers Remain

```bash
# Get VPC ID
VPC_ID=$(podman_terraform output -raw vpc_id)

# Verify no LoadBalancers in VPC
aws elbv2 describe-load-balancers --region eu-central-1 \
  --query "LoadBalancers[?VpcId=='$VPC_ID']"

# Should return empty list: []
```

### Step 4: Destroy Terraform Infrastructure

```bash
cd tf-aws-infra/single-master-k8s

# Destroy all infrastructure
podman_terraform destroy -auto-approve
```

If destroy fails with AWS credential errors:
```bash
podman_terraform destroy -auto-approve -refresh=false
```

### Step 5: Clean Up Local Files

```bash
# Remove kubeconfig
rm ~/.kube/aws-k8s

# Remove Terraform state files (optional, if starting fresh)
rm -rf .terraform/
rm terraform.tfstate*
```

### Troubleshooting Cleanup

**If Terraform destroy fails with DependencyViolation:**

LoadBalancers still exist. Manually delete them:

```bash
# List remaining LoadBalancers
VPC_ID=$(podman_terraform output -raw vpc_id)
aws elbv2 describe-load-balancers --region eu-central-1 \
  --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" \
  --output text

# Delete each LoadBalancer
aws elbv2 delete-load-balancer --region eu-central-1 \
  --load-balancer-arn <ARN-from-above>

# Wait and retry
sleep 120
podman_terraform destroy
```

---

## Migration from Scripts

### What Changes

**Before (Scripts):**
```bash
# Manual deployment
./scripts/deploy-aws-cloud-provider.sh
./scripts/deploy-external-dns.sh
./scripts/deploy-ingress-nginx.sh

# Manual updates
./scripts/deploy-ingress-nginx.sh  # Re-run to update
```

**After (GitOps):**
```bash
# One-time Flux bootstrap
podman_flux bootstrap github ...

# Updates via Git commits
git commit -m "Update config"
git push
# Flux auto-deploys within 2 minutes
```

### Scripts You No Longer Need

❌ `./scripts/deploy-aws-cloud-provider.sh` → Replaced by Flux + ic-aws-stack
❌ `./scripts/deploy-external-dns.sh` → Replaced by Flux + ic-aws-stack
❌ `./scripts/deploy-ingress-nginx.sh` → Replaced by Flux + ic-ingress-stack

### Scripts You Still Use

✅ `./scripts/BOOTSTRAP_KUBE.sh` → Still needed for initial cluster setup
✅ `podman_terraform` → Still needed for infrastructure provisioning

### Benefits of Migration

| Feature | Scripts | GitOps |
|---------|---------|--------|
| Deployment | Manual execution | Automatic |
| Configuration | Hardcoded | Declarative YAML |
| Updates | Re-run scripts | Git commit |
| Drift detection | None | Auto-corrects |
| Rollback | Manual | `git revert` |
| Audit trail | None | Full Git history |
| Multi-environment | Script parameters | Kustomize overlays |

---

## Summary

You've successfully deployed a GitOps-managed Kubernetes cluster:

1. ✅ **Infrastructure**: Deployed via Terraform (`tf-aws-infra`)
2. ✅ **Kubernetes**: Bootstrapped with kubeadm + Calico CNI
3. ✅ **Flux CD**: Installed and watching `ic-gitops-central`
4. ✅ **AWS Components**: Auto-deployed from `ic-aws-stack`
5. ✅ **Ingress**: Auto-deployed from `ic-ingress-stack`
6. ✅ **Applications**: Deployed via Ingress resources

All future changes are made via Git commits - Flux handles the rest!

---

## Quick Reference Commands

```bash
# Flux status
podman_flux get all
podman_flux logs --follow

# Force reconciliation
podman_flux reconcile kustomization flux-system --with-source
podman_flux reconcile kustomization ic-aws --with-source
podman_flux reconcile kustomization ic-ingress --with-source

# Check components
podman_kubectl get pods -A
podman_kubectl get svc -A
podman_kubectl get ingress -A

# Helm releases
podman_flux get helmreleases -A
podman_helm list -A

# Troubleshooting
podman_kubectl describe kustomization ic-aws -n flux-system
podman_kubectl logs -n flux-system -l app=kustomize-controller
```

For more details, see the main README.md in `single-master-k8s/`.
