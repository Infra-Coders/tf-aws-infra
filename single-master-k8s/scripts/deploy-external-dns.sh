#!/bin/bash

set -e

export KUBECONFIG=~/.kube/aws-k8s

# Configuration - Update these values
DOMAIN_FILTER="luke.infra-coders.com"
HOSTED_ZONE_ID="Z02251092DC8UV3YZXE7B"
AWS_REGION="eu-central-1"

echo "Deploying external-dns..."

# Verify cluster connectivity
echo "Verifying cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    echo "Please verify KUBECONFIG is correct: $KUBECONFIG"
    exit 1
fi

# Add official external-dns Helm repository
echo "Adding external-dns Helm repository..."
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/ 2>/dev/null || true
helm repo update

# Create namespace
echo "Creating external-dns namespace..."
kubectl create namespace external-dns --dry-run=client -o yaml | kubectl apply -f -

# Install or upgrade external-dns
echo "Installing/Upgrading external-dns..."
helm upgrade --install external-dns external-dns/external-dns \
  --namespace external-dns \
  --set provider.name=aws \
  --set "domainFilters[0]=${DOMAIN_FILTER}" \
  --set txtOwnerId="${HOSTED_ZONE_ID}" \
  --set policy=sync \
  --set registry=txt \
  --set interval=1m \
  --set "sources[0]=ingress" \
  --set "env[0].name=AWS_DEFAULT_REGION" \
  --set "env[0].value=${AWS_REGION}"

echo "external-dns deployed successfully!"

# Wait for external-dns to be ready
echo "Waiting for external-dns to be ready..."
kubectl wait --for=condition=available --timeout=120s \
  deployment/external-dns -n external-dns

# Verify deployment
echo "Verifying deployment..."
kubectl get pods -n external-dns

echo ""
echo "=========================================="
echo "external-dns is ready!"
echo ""
echo "DNS records will be auto-created for Ingress resources"
echo "with the annotation: external-dns.alpha.kubernetes.io/hostname"
echo ""
echo "Example Ingress annotation:"
echo "  annotations:"
echo "    external-dns.alpha.kubernetes.io/hostname: myapp.${DOMAIN_FILTER}"
echo "=========================================="
