# tf-aws-infra

### Useful links
#### K8s
[install kubeadm](https://v1-32.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)<br>
[cri](https://v1-32.docs.kubernetes.io/docs/concepts/architecture/cri/)<br>
[cri-o](https://cri-o.io/)<br>
[create k8s using kubeadm](https://v1-32.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)<br>
[create HA k8s](https://v1-32.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/)<br>
[kubelet customization](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/)<br>
#### Tiger Operator, Callico
[calico install](https://docs.tigera.io/calico/latest/getting-started/kubernetes/k8s-single-node)<br>
[calico customize](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/config-options)<br>
#### AWS VPC CNI
[amazon-vpc-cni-k8s](https://github.com/aws/amazon-vpc-cni-k8s)

#### AWS Cloud Provider
[cloud-provider-aws](https://github.com/kubernetes/cloud-provider-aws)
[aws-load-balancer-controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)

#### Flux
[flux](https://spacelift.io/blog/fluxcd)<br>
[flux install](https://fluxcd.io/flux/installation/)<br>

### AWS connection

> Note: Check your AWS credentials & update provdider.tf
```
> cat ~/.aws/credentials
> aws configure --profile <your_profile>
AWS Access Key ID [****************PTVK]:
AWS Secret Access Key [****************deH7]:
Default region name [eu-central-1]:
Default output format [json]:
```

> Note: Check connection to AWS
```bash
aws ec2 describe-images --filters Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-* --query 'Images[*].[ImageId,CreationDate]' --output text
```

### Setup Workdir

> Note: Setup Workdir (amd64|arm64)
```bash
git clone git@github.com:Infra-Coders/tf-aws-infra.git
cd tf-aws-infra/ic-utils
./setup_WORKDIR
```

This creates symlinks for `podman_*` utilities in your `~/bin` directory.


### Quick Start - Complete Deployment

Deploy the entire cluster:

```bash
cd tf-aws-infra/single-master-k8s

# Initialize Terraform
podman_terraform init

# Apply Terraform to create infrastructure
podman_terraform apply

# Bootstrap Kubernetes cluster
podman_run ./scripts/BOOTSTRAP_KUBE.sh
```

This will:
1. Create AWS infrastructure (VPC, subnets, EC2 instances, IAM roles)
2. Bootstrap Kubernetes cluster with kubeadm
3. Deploy Calico CNI
4. Deploy AWS Cloud Controller Manager
5. **Automatically set ProviderID on all nodes** via kubeadm configuration
   - Master node: ProviderID set in kubeadm InitConfiguration
   - Worker nodes: ProviderID added to kubeadm join command
6. Configure kubectl access

After deployment completes:
```bash
export KUBECONFIG=~/.kube/aws-k8s
podman_kubectl get nodes -o custom-columns=NAME:.metadata.name,PROVIDER-ID:.spec.providerID
```

**Note:** ProviderID is now automatically configured during node initialization using EC2 metadata service (`169.254.169.254`). No manual patching required.

### Recommended Full Deployment Order

For a complete deployment with TLS and automatic DNS, follow this order:

```bash
# 1. Deploy infrastructure with Terraform
podman_terraform init
podman_terraform apply -auto-approve

# 2. Bootstrap Kubernetes cluster
podman_run ./scripts/BOOTSTRAP_KUBE.sh

# 3. Deploy Ingress NGINX (creates NLB)
podman_run ./scripts/deploy-ingress-nginx.sh

# 4. Deploy external-dns (auto-manages Route 53 DNS)
podman_run ./scripts/deploy-external-dns.sh

# 5. Patch CoreDNS to use Google DNS (prevents VPC DNS caching issues)
podman_kubectl apply -f manifests/coredns-patch.yaml
podman_kubectl rollout restart deployment coredns -n kube-system

# 6. Deploy cert-manager
podman_run ./scripts/deploy-cert-manager.sh

# 7. IMPORTANT: Apply ClusterIssuer (required for TLS certificates!)
podman_kubectl apply -f manifests/clusterissuer-letsencrypt.yaml

# 8. Deploy your applications
podman_kubectl apply -f manifests/example-app-edge-tls.yaml
```

> **⚠️ Common Mistake**: Forgetting step 7 (ClusterIssuer) causes certificates to remain in `READY: False` state.

### Manual Deployment Steps

If you prefer to run each step manually, follow the same order as the recommended deployment:

```bash
# 1. Initialize and apply Terraform
cd tf-aws-infra/single-master-k8s
podman_terraform init
podman_terraform apply -auto-approve

# 2. Bootstrap Kubernetes cluster
podman_run ./scripts/BOOTSTRAP_KUBE.sh

# 3. Deploy Ingress NGINX (creates NLB)
podman_run ./scripts/deploy-ingress-nginx.sh

# 4. Deploy external-dns (auto-manages Route 53 DNS)
podman_run ./scripts/deploy-external-dns.sh

# 5. Patch CoreDNS to use Google DNS (prevents VPC DNS caching issues)
podman_kubectl apply -f manifests/coredns-patch.yaml
podman_kubectl rollout restart deployment coredns -n kube-system

# 6. Deploy cert-manager
podman_run ./scripts/deploy-cert-manager.sh

# 7. IMPORTANT: Apply ClusterIssuer (required for TLS certificates!)
# Edit manifests/clusterissuer-letsencrypt.yaml and change email first
podman_kubectl apply -f manifests/clusterissuer-letsencrypt.yaml

# 8. Deploy your applications
podman_kubectl apply -f manifests/example-app-edge-tls.yaml
```

### Spot vs On-Demand Instances
- Default: workers launch as Spot; masters launch on-demand to keep the control plane stable.
- To disable Spot for workers: `terraform plan -var 'workers_spot_enabled=false'`
- To enable Spot for masters (opt-in, higher risk): `terraform plan -var 'masters_spot_enabled=true'`
- Spot options (shared): `spot_options.max_price` (string, default `null` = on-demand price as maximum).

### Verify Deployment

After bootstrap completes, verify your cluster:

```bash
export KUBECONFIG=~/.kube/aws-k8s
podman_kubectl get nodes
```

Expected output: All nodes should show `Ready` status with appropriate roles (control-plane, worker).

### Deploy AWS Cloud Provider

The AWS Cloud Provider is automatically deployed at the end of the `BOOTSTRAP_KUBE.sh` process using `podman_helm` locally.

**What happens automatically:**
1. **ProviderID is set during node initialization** via kubeadm configuration
   - Master node: `provider-id` set in kubeadm InitConfiguration (`kubeletExtraArgs`)
   - Worker nodes: `provider-id` set in kubeadm JoinConfiguration via `create-join-config.sh`
   - Each node queries EC2 metadata service for instance-id and availability-zone
   - Format: `aws:///availability-zone/instance-id`
2. AWS Cloud Controller Manager is deployed with correct cluster name
3. Nodes are automatically registered for LoadBalancer target management

**Note**: The AWS Cloud Provider is deployed locally (not on control plane) to follow best practices:
- Better security isolation
- No resource consumption on control plane nodes
- Local deployment history tracking
- Version control friendly configurations

If you need to redeploy it manually:
```bash
# Set KUBECONFIG (from BOOTSTRAP_KUBE output)
export KUBECONFIG=~/.kube/aws-k8s

# Deploy AWS Cloud Provider
podman_run ./scripts/deploy-aws-cloud-provider.sh
```

### Deploy Ingress NGINX (Recommended for Cost Efficiency)

**Cost Optimization**: Instead of creating one LoadBalancer per application, use a single NLB with Ingress NGINX for HTTP/HTTPS routing to multiple applications.

**Architecture:**
```
Client → AWS NLB (TCP/443,80) → NodePort → ingress-nginx → HTTP routing → App Services → App Pods
```

**Benefits:**
- Single NLB for all HTTP/HTTPS traffic
- TLS termination at ingress level
- Path-based and host-based routing
- Centralized certificate management

#### Deploy Ingress NGINX Controller

```bash
# Set KUBECONFIG
export KUBECONFIG=~/.kube/aws-k8s

# Deploy Ingress NGINX with NLB
podman_run ./scripts/deploy-ingress-nginx.sh

# Get NLB hostname
podman_kubectl get svc ingress-nginx-controller -n ingress-nginx
```

#### Deploy Example Application with Ingress

```bash
# Deploy example app (uses ClusterIP service + Ingress)
podman_kubectl apply -f manifests/example-app.yaml

# Check ingress
podman_kubectl get ingress

# Test access (replace with your NLB hostname)
curl -H "Host: demo.luke.infra-coders.com" http://<NLB-HOSTNAME>
```

#### Add More Applications

For each new application, create:
1. **Deployment** - Your application pods
2. **Service** - Type: ClusterIP (not LoadBalancer!)
3. **Ingress** - HTTP routing rules

Example:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
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
            name: my-app-service
            port:
              number: 80
```

### Deploy external-dns for Automatic DNS (Optional)

**external-dns** automatically creates/deletes Route 53 DNS records when you create/delete Ingress resources.

```bash
# Set KUBECONFIG
export KUBECONFIG=~/.kube/aws-k8s

# Deploy external-dns
podman_run ./scripts/deploy-external-dns.sh
```

**Note**: Requires IAM permissions for Route 53. If deploying to existing cluster, run `podman_terraform apply` first to add the new IAM policy.

DNS records are auto-managed via Ingress annotation:
```yaml
annotations:
  external-dns.alpha.kubernetes.io/hostname: "myapp.luke.infra-coders.com"
```

### Deploy cert-manager for TLS/HTTPS (Optional)

**cert-manager** automates TLS certificate management using Let's Encrypt.

#### Deploy cert-manager

```bash
export KUBECONFIG=~/.kube/aws-k8s

# Deploy cert-manager
podman_run ./scripts/deploy-cert-manager.sh

# IMPORTANT: Apply ClusterIssuer (required for certificates to work!)
# Edit manifests/clusterissuer-letsencrypt.yaml and change email first
podman_kubectl apply -f manifests/clusterissuer-letsencrypt.yaml
```

> **⚠️ Common Issue**: If certificates show `READY: False`, ensure you applied the ClusterIssuer above.

#### TLS Termination Strategies

**1. Edge Termination (Recommended for most apps)**
- cert-manager provisions certificates automatically
- TLS terminates at ingress-nginx
- Traffic from ingress to pod is HTTP (inside cluster)
- Simpler application code

```bash
# Deploy app with automatic TLS from Let's Encrypt
# Edit manifests/example-app-edge-tls.yaml and change domain/email
podman_kubectl apply -f manifests/example-app-edge-tls.yaml

# Check certificate status
podman_kubectl get certificate
podman_kubectl describe certificate nginx-edge-tls-cert
```

**2. Passthrough (For end-to-end encryption)**
- Application handles its own TLS
- Ingress forwards encrypted traffic to pod
- Traffic remains encrypted from client to pod
- Application must serve HTTPS

```bash
# Deploy app that handles its own TLS
# Edit manifests/example-app-passthrough-tls.yaml and change domain
podman_kubectl apply -f manifests/example-app-passthrough-tls.yaml
```

**Let's Encrypt Rate Limits:**
- Staging: Unlimited (use for testing)
- Production: 50 certificates/week per domain

Always test with `letsencrypt-staging` issuer first, then switch to `letsencrypt-prod`.

### Test AWS Cloud Provider (Direct LoadBalancer)

**Note**: This creates a separate LoadBalancer per service. Use Ingress NGINX instead for cost efficiency.

```bash
# Deploy test nginx with LoadBalancer
podman_kubectl create deployment nginx --image=nginx
podman_kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Get LoadBalancer URL
podman_kubectl get svc nginx -w
```

## Cleanup

### Quick Full Cleanup (Recommended)

Use the cleanup script to remove all deployed resources in the correct order:

```bash
export KUBECONFIG=~/.kube/aws-k8s

# Run full cleanup script
podman_run ./scripts/cleanup-all.sh
```

This script removes (in order):
1. Example applications
2. ClusterIssuers and certificates
3. cert-manager
4. external-dns
5. ingress-nginx (and its NLB)

### Manual Cleanup Steps

If you prefer manual cleanup or need to remove specific components:

### Remove external-dns (if deployed)

To remove external-dns:

```bash
export KUBECONFIG=~/.kube/aws-k8s

# 1. Uninstall external-dns (DNS records will be auto-deleted by sync policy)
podman_helm uninstall external-dns -n external-dns

# 2. Delete the namespace
podman_kubectl delete namespace external-dns
```

**Note**: With `policy=sync`, external-dns automatically deletes DNS records when Ingress resources are removed. Records are also cleaned up when external-dns is uninstalled.

### Remove cert-manager and TLS Applications (if deployed)

To remove cert-manager and TLS-enabled applications:

```bash
export KUBECONFIG=~/.kube/aws-k8s

# 1. Delete TLS example applications
podman_kubectl delete -f manifests/example-app-edge-tls.yaml 2>/dev/null || true
podman_kubectl delete -f manifests/example-app-passthrough-tls.yaml 2>/dev/null || true

# 2. Delete ClusterIssuers (removes Let's Encrypt configuration)
podman_kubectl delete -f manifests/clusterissuer-letsencrypt.yaml 2>/dev/null || true

# 3. Delete any remaining certificates and secrets
podman_kubectl delete certificate --all -n default
podman_kubectl get secret -n default | grep tls | awk '{print $1}' | xargs -r podman_kubectl delete secret -n default

# 4. Uninstall cert-manager
podman_helm uninstall cert-manager -n cert-manager 2>/dev/null || true

# 5. Delete cert-manager namespace and CRDs
podman_kubectl delete namespace cert-manager
```

**Note**: cert-manager CRDs will remain. To remove them completely:
```bash
podman_kubectl delete crd certificates.cert-manager.io
podman_kubectl delete crd certificaterequests.cert-manager.io
podman_kubectl delete crd challenges.acme.cert-manager.io
podman_kubectl delete crd clusterissuers.cert-manager.io
podman_kubectl delete crd issuers.cert-manager.io
podman_kubectl delete crd orders.acme.cert-manager.io
```

### Remove Ingress NGINX (if deployed)

To remove only the ingress-nginx namespace and its NLB:

```bash
export KUBECONFIG=~/.kube/aws-k8s

# 1. Delete all Ingress resources in default namespace
podman_kubectl delete ingress --all -n default

# 2. Delete example applications
podman_kubectl delete -f manifests/example-app.yaml

# 3. Uninstall Ingress NGINX (removes NLB)
podman_helm uninstall ingress-nginx -n ingress-nginx

# 4. Delete the namespace
podman_kubectl delete namespace ingress-nginx

# 5. Wait for AWS to clean up the NLB (2-3 minutes)
sleep 180
```

### Destroy Complete Infrastructure

**IMPORTANT**: Delete all LoadBalancer services first to avoid orphaned AWS resources.

```bash
export KUBECONFIG=~/.kube/aws-k8s

# 1. Delete cert-manager (if deployed) - see above

# 2. Delete Ingress NGINX (if deployed) - see above

# 3. Delete any other LoadBalancer services you created
podman_kubectl get svc --all-namespaces -o wide | grep LoadBalancer
# Delete each LoadBalancer service individually:
podman_kubectl delete svc <service-name> -n <namespace>

# 4. Wait for AWS to clean up all LoadBalancers (3 minutes)
sleep 180

# 5. Verify no LoadBalancers remain in your VPC
VPC_ID=$(podman_terraform output -raw vpc_id)
aws elbv2 describe-load-balancers --region eu-central-1 \
  --query "LoadBalancers[?VpcId=='$VPC_ID']"

# 6. Destroy Terraform infrastructure
podman_terraform destroy -auto-approve

# Note: If you get AWS credential errors, use -refresh=false to skip state refresh
```

### Troubleshooting: Terraform Destroy Fails

If `terraform destroy` fails with "DependencyViolation", LoadBalancers still exist:

```bash
# List remaining LoadBalancers
VPC_ID=$(podman_terraform output -raw vpc_id)
aws elbv2 describe-load-balancers --region eu-central-1 \
  --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" \
  --output text

# Manually delete each LoadBalancer
aws elbv2 delete-load-balancer --region eu-central-1 \
  --load-balancer-arn <ARN-from-above>

# Wait and retry
sleep 120
podman_terraform destroy
```

### AWS Cloud Provider Issues
If LoadBalancers are not being created:
- Verify IAM roles have correct permissions
- Check cloud controller manager logs:
  ```bash
  kubectl logs -n kube-system -l k8s-app=aws-cloud-controller-manager
  ```