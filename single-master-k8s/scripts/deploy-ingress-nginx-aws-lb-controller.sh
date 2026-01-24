#!/bin/bash

set -e

export KUBECONFIG=~/.kube/aws-k8s

INGRESS_NAMESPACE="ingress-nginx"
VALUES_FILE="examples/nginx_ingress/aws_lb_controller_NLB/ingress-nginx-values.yaml"
CENTRAL_NLB_SVC="examples/nginx_ingress/aws_lb_controller_NLB/svc_CENTRAL_NLB.yaml"

echo "Deploying Ingress NGINX Controller (AWS LB Controller + Central NLB)..."

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
kubectl create namespace ${INGRESS_NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -

# Install / Upgrade ingress-nginx (NodePort)
echo "Installing/Upgrading ingress-nginx (NodePort)..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ${INGRESS_NAMESPACE} \
  --values ${VALUES_FILE}

# Deploy central NLB Service (AWS LB Controller)
echo "Applying central NLB Service manifest..."
kubectl apply -f ${CENTRAL_NLB_SVC}

# Wait for NLB to be provisioned
echo "Waiting for central NLB to be provisioned..."

for i in {1..60}; do
    LB_HOSTNAME=$(kubectl get svc ingress-nlb -n ${INGRESS_NAMESPACE} \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

    if [ -n "$LB_HOSTNAME" ]; then
        echo "Central NLB provisioned!"
        echo "NLB Hostname: $LB_HOSTNAME"
        break
    fi

    echo "Waiting for NLB... ($i/60)"
    sleep 10
done

# Verify deployment
echo "Verifying ingress-nginx deployment..."
kubectl get pods -n ${INGRESS_NAMESPACE}
kubectl get svc -n ${INGRESS_NAMESPACE}

echo ""
echo "===================================================="
echo "Ingress NGINX (AWS LB Controller + Central NLB) READY"
echo "Central NLB Hostname: $LB_HOSTNAME"
echo "===================================================="
