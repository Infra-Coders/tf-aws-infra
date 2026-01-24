# Kubernetes on AWS - Single Master Cluster

Production-ready Kubernetes cluster on AWS using kubeadm, Calico CNI with eBPF dataplane, and optional AWS integrations.

## Table of Contents
- [Prerequisites](#prerequisites)
- [1. Bootstrap Cluster](#1-bootstrap-cluster)
- [2. AWS Cloud Controller Manager (Optional)](#2-aws-cloud-controller-manager-optional)
- [3. AWS Load Balancer Controller (Optional)](#3-aws-load-balancer-controller-optional)
- [4. Ingress NGINX](#4-ingress-nginx)
- [5. External DNS (Optional)](#5-external-dns-optional)
- [6. Cert-Manager (Optional)](#6-cert-manager-optional)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)
- [Reference Links](#reference-links)

---

## Prerequisites

### AWS Credentials

Configure AWS credentials:
```bash
aws configure --profile <your_profile>
# AWS Access Key ID: ****************
# AWS Secret Access Key: ****************
# Default region: eu-central-1
# Default output format: json
```

Verify connection:
```bash
aws ec2 describe-images --filters Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-* --query 'Images[*].[ImageId,CreationDate]' --output text
```

### Setup Workdir

Clone repository and setup utilities:
```bash
git clone git@github.com:Infra-Coders/tf-aws-infra.git
cd tf-aws-infra/ic-utils
./setup_WORKDIR
```

This creates symlinks for `podman_*` utilities in your `~/bin` directory.

### Spot vs On-Demand Instances
- **Default**: Workers launch as Spot instances; masters launch on-demand for control plane stability
- Disable Spot for workers: `terraform plan -var 'workers_spot_enabled=false'`
- Enable Spot for masters: `terraform plan -var 'masters_spot_enabled=true'`
- Control max price: `spot_options.max_price` (default: `null` = on-demand price)

---

## 1. Bootstrap Cluster

Deploy basic Kubernetes cluster with Calico CNI.

### Deploy

```bash
cd tf-aws-infra/single-master-k8s

# Initialize Terraform
podman_terraform init

# Create AWS infrastructure
podman_terraform apply

# Bootstrap Kubernetes cluster
podman_run ./scripts/BOOTSTRAP_KUBE.sh
```

### What Gets Deployed

**Infrastructure:**
- VPC with public/private subnets across availability zones
- EC2 instances (1 master, 3 workers by default)
- Security groups, IAM roles, instance profiles
- EC2 metadata service (IMDSv2 enforced)

**Kubernetes:**
- Kubernetes v1.32.10 via kubeadm
- Calico CNI with eBPF dataplane (pod network: 10.244.0.0/16)
- CRI-O container runtime
- CoreDNS patched to use Google DNS (8.8.8.8) to avoid VPC DNS caching
- **ProviderID automatically set** on all nodes via kubeadm configuration

### Verify Deployment

```bash
export KUBECONFIG=~/.kube/aws-k8s

# Check nodes
podman_kubectl get nodes -o wide

# Verify ProviderID is set
podman_kubectl get nodes -o custom-columns=NAME:.metadata.name,PROVIDER-ID:.spec.providerID

# Check pods
podman_kubectl get pods -A
```

Expected output: All nodes `Ready`, all pods `Running`, ProviderID format `aws:///eu-central-1a/i-xxxxx`.

---

## 2. AWS Cloud Controller Manager (Optional)

Deploy AWS Cloud Controller Manager for native AWS integration and LoadBalancer provisioning.

### When to Deploy

**Deploy if you need:**
- LoadBalancer services (automatic AWS NLB/CLB provisioning)
- Node lifecycle management by AWS
- Cloud-aware Kubernetes operations

**Skip if:**
- You only need Ingress NGINX for HTTP/HTTPS routing (more cost-effective)

### Deploy

```bash
export KUBECONFIG=~/.kube/aws-k8s
podman_run ./scripts/deploy-aws-cloud-provider.sh
```

### Verify

```bash
# Check cloud controller manager pod
podman_kubectl get pods -n kube-system -l k8s-app=aws-cloud-controller-manager

# Test with a LoadBalancer service
podman_kubectl create deployment test-nginx --image=nginx
podman_kubectl expose deployment test-nginx --port=80 --type=LoadBalancer

# Watch for EXTERNAL-IP (takes 2-3 minutes)
podman_kubectl get svc test-nginx -w

# Clean up test
podman_kubectl delete svc test-nginx
podman_kubectl delete deployment test-nginx
```

### What It Provides

- **LoadBalancer services**: Automatically provisions AWS NLB/CLB
- **Node management**: Syncs node metadata with AWS EC2
- **Cloud integration**: Enables cloud-aware scheduling and operations

**Cost Note**: Each LoadBalancer service creates a separate AWS NLB (~$16-20/month). For HTTP/HTTPS traffic, use Ingress NGINX instead (single NLB for all apps).

---

## 3. AWS Load Balancer Controller (Optional)

Deploy AWS Load Balancer Controller for managing AWS load balancers via explicit Kubernetes resources.

This is required for Ingress NGINX Variant 2 (AWS Load Balancer Controller + central NLB).

### When to Deploy

**Deploy if you need:**
- Ingress NGINX Variant 2 (recommended)
- Fine-grained AWS permissions / future-proof design

**Skip if:**
- You only use Ingress NGINX Variant 1 (cloud-provider-aws creates the NLB)

### Deploy

```bash
export KUBECONFIG=~/.kube/aws-k8s
podman_run ./scripts/deploy-aws-cloud-provider.sh
podman_run ./scripts/deploy-aws-lb-controller.sh
```

### Verify

```bash
podman_kubectl get pods -n kube-system -l k8s-app=aws-cloud-controller-manager
podman_kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

---

## 4. Ingress NGINX

Deploy Ingress NGINX for cost-efficient HTTP/HTTPS routing using a single, central AWS Network Load Balancer (NLB) shared by all applications.

This platform supports two equivalent ingress deployment variants. Both expose the same interface to application teams (Ingress objects), but differ in how the NLB is created and managed.

### Architecture

```
Internet → AWS NLB (TCP/443,80) → NodePort → ingress-nginx → ClusterIP Services → Pods
```

### Variant 1: AWS Cloud Provider + Central NLB (Legacy)

In this variant, the NLB is created automatically from the `ingress-nginx` Service `type=LoadBalancer` (managed by `cloud-provider-aws`).

**Deploy**

```bash
export KUBECONFIG=~/.kube/aws-k8s

# (Optional) deploy cloud-provider-aws if you need Kubernetes-managed LoadBalancers
podman_run ./scripts/deploy-aws-cloud-provider.sh

# Deploy ingress-nginx with Service type=LoadBalancer
podman_run ./scripts/deploy-ingress-nginx-aws-cloud-provider.sh
```

**Verify**

```bash
# Get NLB hostname (wait 2-3 minutes for provisioning)
podman_kubectl get svc ingress-nginx-controller -n ingress-nginx
```

### Variant 2: AWS Load Balancer Controller + Central NLB (Recommended)

In this variant, `ingress-nginx` runs behind NodePort, and a separate Service (`ingress-nlb`) owns the NLB (managed by AWS Load Balancer Controller).

**Deploy**

```bash
export KUBECONFIG=~/.kube/aws-k8s

# Deploy ingress-nginx (NodePort) + central NLB service
podman_run ./scripts/deploy-ingress-nginx-aws-lb-controller.sh
```

**Verify**

```bash
# Get NLB hostname (wait 2-3 minutes for provisioning)
podman_kubectl get svc ingress-nlb -n ingress-nginx
```

### Benefits

- **Cost optimization**: Single NLB for all HTTP/HTTPS traffic (vs. one per app)
- **TLS termination**: Centralized certificate management
- **Routing**: Host-based and path-based routing
- **Load balancing**: Distributes traffic across pods

### Deploy Example Application

```bash
# Deploy sample app with Ingress
podman_kubectl apply -f examples/manifests/example-app.yaml

# Check Ingress
podman_kubectl get ingress

# Test (replace <NLB-HOSTNAME> with actual value from above)
curl -H "Host: demo.luke.infra-coders.com" http://<NLB-HOSTNAME>
```

### Deploy Your Own Application (Both Ingress Variants)

The following application pattern works with both Variant 1 and Variant 2.

**Platform contract:**
- Application teams do not create `LoadBalancer` Services
- Application teams do not create `NodePort` Services
- Application teams create only:
  - `Deployment`
  - `Service` (`ClusterIP`)
  - `Ingress`

#### Option A: Pure Kubernetes manifests

Create three resources for each application:

**1. Deployment** (your application):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
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

**2. Service** (use ClusterIP, not LoadBalancer):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  type: ClusterIP
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
```

**3. Ingress** (routing rules):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: myapp.example.com
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

Apply:
```bash
podman_kubectl apply -f myapp.yaml
```

#### Option B: Helm chart examples

Two example charts are provided under `examples/`.

**Edge TLS (default application pattern)**

```bash
podman_helm install my-edge-app ./examples/edge-app \
  --set ingress.host=edge.myteam.infra-coders.com
```

**TLS passthrough (advanced / opt-in)**

```bash
podman_helm install my-passthrough-app ./examples/passthrough-app \
  --set ingress.host=secure.myteam.infra-coders.com
```

Note: TLS passthrough requires ingress-nginx started with `--enable-ssl-passthrough`.

---

## 5. External DNS (Optional)

Automatically manage Route 53 DNS records when creating/deleting Ingress resources.

### Prerequisites

- Route 53 hosted zone in your AWS account
- Domain configured to use Route 53 nameservers

### Deploy

```bash
export KUBECONFIG=~/.kube/aws-k8s
podman_run ./scripts/deploy-external-dns.sh
```

**Note**: Requires IAM permissions for Route 53. If deploying to existing cluster, run `podman_terraform apply` first to add the IAM policy.

### Usage

Add annotation to your Ingress resources:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    external-dns.alpha.kubernetes.io/hostname: "myapp.example.com"
spec:
  rules:
  - host: myapp.example.com
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

external-dns will automatically:
- Create A record pointing to NLB when Ingress is created
- Delete record when Ingress is deleted
- Update records when NLB changes

### Verify

```bash
# Check external-dns logs
podman_kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns

# Verify DNS record in Route 53
aws route53 list-resource-record-sets --hosted-zone-id <YOUR_ZONE_ID>
```

---

## 6. Cert-Manager (Optional)

Automate TLS certificate management using Let's Encrypt.

### Deploy

```bash
export KUBECONFIG=~/.kube/aws-k8s

# Deploy cert-manager
podman_run ./scripts/deploy-cert-manager.sh

# IMPORTANT: Apply ClusterIssuer (required for certificates!)
# Edit examples/cert-manager/clusterissuer-letsencrypt.yaml and change email first
podman_kubectl apply -f examples/cert-manager/clusterissuer-letsencrypt.yaml
```

### TLS Termination: Edge (Recommended)

**How it works:**
- cert-manager automatically provisions Let's Encrypt certificates
- TLS terminates at ingress-nginx
- Traffic from ingress to pod is HTTP (inside cluster)
- Simpler application code (no TLS handling needed)

**Deploy example:**
```bash
# Edit examples/manifests/example-app-edge-tls.yaml:
# - Change domain to your domain
# - Change email in certificate annotation
podman_kubectl apply -f examples/manifests/example-app-edge-tls.yaml

# Check certificate status
podman_kubectl get certificate
podman_kubectl describe certificate <cert-name>
```

**Certificate manifest structure:**
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-tls
spec:
  secretName: myapp-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - myapp.example.com
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    external-dns.alpha.kubernetes.io/hostname: "myapp.example.com"
spec:
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls-secret
  rules:
  - host: myapp.example.com
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

### TLS Termination: Passthrough (Advanced)

**When to use:**
- End-to-end encryption required
- Application handles its own TLS
- Compliance requirements for encrypted traffic inside cluster

**How it works:**
- Application serves HTTPS
- Ingress forwards encrypted traffic to pod
- Traffic remains encrypted from client to pod

**Deploy example:**
```bash
# Edit examples/manifests/example-app-passthrough-tls.yaml and change domain
podman_kubectl apply -f examples/manifests/example-app-passthrough-tls.yaml
```

### Troubleshooting: DNS Not Resolving

**Symptoms**: After deploying Ingress with external-dns annotation, `dig` or `curl` return "Could not resolve host" or NXDOMAIN.

**Root Cause**: Route 53 alias record propagation delay. Records appear immediately in the Route 53 API but can take 1-3 minutes to propagate to all nameservers.

**Diagnosis**:

```bash
# 1. Verify records exist in Route 53
ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='your-domain.com.'].Id" --output text | cut -d'/' -f3)
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID --query "ResourceRecordSets[?Name=='your-app.your-domain.com.']"

# 2. Test DNS resolution against Route 53 nameservers
# Get nameservers for your zone
aws route53 get-hosted-zone --id $ZONE_ID --query "DelegationSet.NameServers"

# Test each nameserver directly
dig @ns-541.awsdns-03.net your-app.your-domain.com A

# 3. Check external-dns logs for errors
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=50
```

**Solution**: If records exist in Route 53 API but nameservers return NXDOMAIN, recreate the Ingress to force fresh DNS records:

```bash
# Delete Ingress (external-dns will delete stale DNS records)
kubectl delete ingress <your-ingress-name>

# Wait for deletion to complete (check external-dns logs)
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=20

# Recreate Ingress (external-dns will create fresh DNS records)
kubectl apply -f your-ingress.yaml

# Wait 2-3 minutes for propagation, then test
dig your-app.your-domain.com +short
```

**Prevention**: After creating new Ingress resources with external-dns annotations, wait 2-3 minutes before testing DNS resolution.

### Let's Encrypt Rate Limits

**Important**: Test with staging first, then switch to production.

- **Staging issuer** (`letsencrypt-staging`): Unlimited certificates (use for testing)
- **Production issuer** (`letsencrypt-prod`): 50 certificates/week per domain

### Troubleshooting Certificates

If certificate shows `READY: False`:

```bash
# 1. Verify ClusterIssuer exists
podman_kubectl get clusterissuer

# 2. Check certificate details
podman_kubectl describe certificate <cert-name>

# 3. Check certificate request
podman_kubectl get certificaterequest
podman_kubectl describe certificaterequest <request-name>

# 4. Check ACME challenge
podman_kubectl get challenge
podman_kubectl describe challenge <challenge-name>

# 5. Check cert-manager logs
podman_kubectl logs -n cert-manager -l app=cert-manager
```

Common issues:
- ClusterIssuer not applied
- DNS not pointing to NLB yet
- Firewall blocking Let's Encrypt validation (ports 80/443)

---

## Cleanup

**IMPORTANT**: Always remove Kubernetes resources before destroying Terraform infrastructure to avoid orphaned AWS resources (LoadBalancers, security groups, etc.).

### Step 1: Remove Applications and TLS Certificates

```bash
export KUBECONFIG=~/.kube/aws-k8s

# Delete your applications
podman_kubectl delete -f your-app.yaml

# Delete TLS example applications
podman_kubectl delete -f examples/manifests/example-app-edge-tls.yaml
podman_kubectl delete -f examples/manifests/example-app-passthrough-tls.yaml

# Delete ClusterIssuers
podman_kubectl delete -f examples/cert-manager/clusterissuer-letsencrypt.yaml

# Delete remaining certificates and secrets
podman_kubectl delete certificate --all -n default
podman_kubectl get secret -n default | grep tls | awk '{print $1}' | xargs -r podman_kubectl delete secret -n default
```

### Step 2: Remove cert-manager (if deployed)

```bash
# Uninstall cert-manager
podman_helm uninstall cert-manager -n cert-manager

# Delete namespace
podman_kubectl delete namespace cert-manager

# Optional: Remove CRDs
podman_kubectl delete crd certificates.cert-manager.io
podman_kubectl delete crd certificaterequests.cert-manager.io
podman_kubectl delete crd challenges.acme.cert-manager.io
podman_kubectl delete crd clusterissuers.cert-manager.io
podman_kubectl delete crd issuers.cert-manager.io
podman_kubectl delete crd orders.acme.cert-manager.io
```

### Step 3: Remove external-dns (if deployed)

```bash
# Uninstall external-dns (DNS records auto-deleted with policy=sync)
podman_helm uninstall external-dns -n external-dns

# Delete namespace
podman_kubectl delete namespace external-dns
```

### Step 4: Remove Ingress NGINX (if deployed)

```bash
# Delete all Ingress resources
podman_kubectl delete ingress --all -n default

# Delete example apps
podman_kubectl delete -f examples/manifests/example-app.yaml

# Uninstall Ingress NGINX
podman_helm uninstall ingress-nginx -n ingress-nginx

# If using the AWS LB Controller + central NLB variant, also remove the central Service
podman_kubectl delete svc ingress-nlb -n ingress-nginx

# Delete namespace
podman_kubectl delete namespace ingress-nginx

# Wait for AWS to clean up NLB
sleep 180
```

### Step 5: Remove AWS Cloud Controller (if deployed)

```bash
# Uninstall AWS cloud controller
podman_helm uninstall aws-cloud-controller-manager -n kube-system
```

### Step 6: Remove Any Other LoadBalancer Services

```bash
# List all LoadBalancer services
podman_kubectl get svc --all-namespaces -o wide | grep LoadBalancer

# Delete each LoadBalancer service
podman_kubectl delete svc <service-name> -n <namespace>

# Wait for AWS cleanup
sleep 180
```

### Step 7: Verify No LoadBalancers Remain

```bash
# Get VPC ID
VPC_ID=$(podman_terraform output -raw vpc_id)

# Verify no LoadBalancers in VPC
aws elbv2 describe-load-balancers --region eu-central-1 \
  --query "LoadBalancers[?VpcId=='$VPC_ID']"

# Should return empty list: []
```

### Step 8: Destroy Terraform Infrastructure

```bash
podman_terraform destroy -auto-approve
```

If destroy fails with AWS credential errors:
```bash
podman_terraform destroy -auto-approve -refresh=false
```

---

## Troubleshooting

### Terraform Destroy Fails with DependencyViolation

LoadBalancers still exist in VPC. Manually delete them:

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

### AWS Cloud Controller LoadBalancers Not Created

Check IAM permissions and controller logs:

```bash
# Verify IAM role attached to instances
aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'

# Check cloud controller logs
podman_kubectl logs -n kube-system -l k8s-app=aws-cloud-controller-manager
```

### Ingress Not Accessible

```bash
# 1. Check Ingress exists and has address
podman_kubectl get ingress

# 2. Check ingress-nginx pods running
podman_kubectl get pods -n ingress-nginx

# 3. Check NLB exists and is active
podman_kubectl get svc ingress-nginx-controller -n ingress-nginx

# 4. Check ingress controller logs
podman_kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx

# 5. Test with curl
curl -v -H "Host: yourapp.example.com" http://<NLB-HOSTNAME>
```

### Certificates Not Issued

```bash
# Check certificate status
podman_kubectl get certificate
podman_kubectl describe certificate <cert-name>

# Check ACME challenges
podman_kubectl get challenge
podman_kubectl describe challenge <challenge-name>

# Check cert-manager logs
podman_kubectl logs -n cert-manager -l app=cert-manager

# Common issues:
# - ClusterIssuer not applied
# - DNS not resolving to NLB yet
# - Ports 80/443 blocked
```

---

## Reference Links

### Kubernetes
- [Install kubeadm](https://v1-32.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [CRI-O Container Runtime](https://cri-o.io/)
- [Create cluster with kubeadm](https://v1-32.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [Kubelet customization](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/)

### Calico
- [Calico installation](https://docs.tigera.io/calico/latest/getting-started/kubernetes/k8s-single-node)
- [Calico configuration](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/config-options)

### AWS Integration
- [AWS Cloud Provider](https://github.com/kubernetes/cloud-provider-aws)
- [AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)
- [AWS VPC CNI](https://github.com/aws/amazon-vpc-cni-k8s)

### GitOps
- [FluxCD](https://spacelift.io/blog/fluxcd)
- [Flux installation](https://fluxcd.io/flux/installation/)
