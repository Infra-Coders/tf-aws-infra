#!/bin/bash

set -e

export KUBECONFIG=~/.kube/aws-k8s

echo "Deploying cert-manager..."

# Verify cluster connectivity
echo "Verifying cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    echo "Please verify KUBECONFIG is correct: $KUBECONFIG"
    exit 1
fi

# Add Jetstack Helm repository
echo "Adding Jetstack Helm repository..."
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update

# Create namespace
echo "Creating cert-manager namespace..."
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -

# Install or upgrade cert-manager
echo "Installing/Upgrading cert-manager..."
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set crds.enabled=true \
  --set crds.keep=true

echo "cert-manager deployed successfully!"

# Wait for cert-manager to be ready
echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s \
  deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=available --timeout=300s \
  deployment/cert-manager-cainjector -n cert-manager

# Verify deployment
echo "Verifying deployment..."
kubectl get pods -n cert-manager

echo ""
echo "=========================================="
echo "cert-manager is ready!"
echo ""
echo "Next steps:"
echo "1. Apply ClusterIssuer: kubectl apply -f examples/cert-manager/clusterissuer-letsencrypt.yaml"
echo "2. Deploy apps with TLS (see examples in examples/manifests/)"
echo "=========================================="
