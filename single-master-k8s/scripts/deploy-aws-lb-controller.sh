#!/bin/bash

set -e

export KUBECONFIG=~/.kube/aws-k8s

CLUSTER_NAME="ic-k8slab"
NAMESPACE="kube-system"

echo "Deploying AWS Load Balancer Controller using Helm..."

# Verify cluster connectivity
echo "Verifying cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    echo "Please verify KUBECONFIG is correct: $KUBECONFIG"
    exit 1
fi

# Add Helm repo
echo "Adding AWS Load Balancer Controller Helm repository..."
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update

# Install / Upgrade controller
echo "Installing/Upgrading AWS Load Balancer Controller..."
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace ${NAMESPACE} \
  --set clusterName=${CLUSTER_NAME} \
  --set region=eu-central-1 \
  --set v=2 \
  --set replicaCount=1 \
  --set nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set tolerations[0].key=node-role.kubernetes.io/control-plane \
  --set tolerations[0].operator=Exists \
  --set tolerations[0].effect=NoSchedule \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller

echo "AWS Load Balancer Controller deployment triggered."

# Verify deployment
echo "Verifying deployment..."
for i in {1..30}; do
    if kubectl get pods -n ${NAMESPACE} \
        -l app.kubernetes.io/name=aws-load-balancer-controller \
        2>/dev/null | grep -q Running; then

        echo "AWS Load Balancer Controller is running!"
        kubectl get pods -n ${NAMESPACE} \
          -l app.kubernetes.io/name=aws-load-balancer-controller
        exit 0
    fi

    echo "Waiting for controller to be ready... ($i/30)"
    sleep 2
done

echo "WARNING: Controller is not running yet."
kubectl get pods -n ${NAMESPACE} \
  -l app.kubernetes.io/name=aws-load-balancer-controller
