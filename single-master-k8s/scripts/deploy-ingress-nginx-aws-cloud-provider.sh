#!/bin/bash

set -e

export KUBECONFIG=~/.kube/aws-k8s

echo "Deploying Ingress NGINX Controller..."

# Verify cluster connectivity
echo "Verifying cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    echo "Please verify KUBECONFIG is correct: $KUBECONFIG"
    exit 1
fi

# Add Ingress NGINX Helm repository
echo "Adding Ingress NGINX Helm repository..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update

# Create namespace
echo "Creating ingress-nginx namespace..."
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

# Install or upgrade Ingress NGINX
echo "Installing/Upgrading Ingress NGINX..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --values examples/nginx_ingress/aws_cloud_provider_NLB/ingress-nginx-values.yaml

echo "Ingress NGINX deployed successfully!"

# Wait for LoadBalancer to be provisioned
echo "Waiting for LoadBalancer to be provisioned..."
for i in {1..60}; do
    LB_HOSTNAME=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$LB_HOSTNAME" ]; then
        echo "LoadBalancer provisioned!"
        echo "NLB Hostname: $LB_HOSTNAME"
        break
    fi
    echo "Waiting for LoadBalancer... ($i/60)"
    sleep 5
done

# Verify deployment
echo "Verifying deployment..."
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

echo ""
echo "=========================================="
echo "Ingress NGINX Controller is ready!"
echo "NLB Hostname: $LB_HOSTNAME"
echo "=========================================="
