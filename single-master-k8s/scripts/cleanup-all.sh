#!/bin/bash

# Full cleanup script for Kubernetes cluster and all deployed resources
# This script removes everything in reverse deployment order

set -e

export KUBECONFIG=~/.kube/aws-k8s

echo "=============================================="
echo "FULL CLEANUP - Removing all deployed resources"
echo "=============================================="
echo ""
echo "This will remove:"
echo "  - Example applications (edge-tls, passthrough-tls)"
echo "  - cert-manager and ClusterIssuers"
echo "  - external-dns"
echo "  - ingress-nginx (and its NLB)"
echo ""

# Check if running in interactive mode
if [ -t 0 ]; then
    read -p "Are you sure you want to continue? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi
else
    echo "Running in non-interactive mode - proceeding with cleanup..."
fi

echo ""
echo "Step 1/7: Removing example applications..."
kubectl delete -f manifests/example-app-edge-tls.yaml 2>/dev/null || true
kubectl delete -f manifests/example-app-passthrough-tls.yaml 2>/dev/null || true
kubectl delete -f manifests/example-app.yaml 2>/dev/null || true
echo "  Done."

echo ""
echo "Step 2/7: Removing ClusterIssuers..."
kubectl delete -f manifests/clusterissuer-letsencrypt.yaml 2>/dev/null || true
echo "  Done."

echo ""
echo "Step 3/7: Removing certificates and secrets..."
kubectl delete certificate --all -n default 2>/dev/null || true
kubectl get secret -n default 2>/dev/null | grep -E "tls|cert" | awk '{print $1}' | xargs -r kubectl delete secret -n default 2>/dev/null || true
echo "  Done."

echo ""
echo "Step 4/7: Uninstalling cert-manager..."
helm uninstall cert-manager -n cert-manager 2>/dev/null || true
kubectl delete namespace cert-manager 2>/dev/null || true
echo "  Done."

echo ""
echo "Step 5/7: Uninstalling external-dns..."
helm uninstall external-dns -n external-dns 2>/dev/null || true
kubectl delete namespace external-dns 2>/dev/null || true
echo "  Done."

echo ""
echo "Step 6/7: Removing all Ingress resources..."
kubectl delete ingress --all -n default 2>/dev/null || true
echo "  Done."

echo ""
echo "Step 7/7: Uninstalling ingress-nginx (this removes the NLB)..."
helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || true
kubectl delete namespace ingress-nginx 2>/dev/null || true
echo "  Done."

echo ""
echo "=============================================="
echo "Waiting for AWS to clean up LoadBalancers..."
echo "This may take 2-3 minutes..."
echo "=============================================="
sleep 30

# Check for remaining LoadBalancers
echo ""
echo "Checking for remaining LoadBalancer services..."
REMAINING=$(kubectl get svc --all-namespaces 2>/dev/null | grep LoadBalancer || true)
if [ -n "$REMAINING" ]; then
    echo "WARNING: The following LoadBalancer services still exist:"
    echo "$REMAINING"
    echo ""
    echo "Please delete them manually before running 'terraform destroy'"
else
    echo "No LoadBalancer services remaining."
fi

echo ""
echo "=============================================="
echo "CLEANUP COMPLETE"
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. Wait 2-3 more minutes for AWS to fully clean up NLB"
echo "  2. Verify no LoadBalancers remain:"
echo "     aws elbv2 describe-load-balancers --query 'LoadBalancers[*].DNSName'"
echo "  3. Then run: podman_terraform destroy"
echo ""
