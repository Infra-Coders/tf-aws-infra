#!/bin/bash

set -e

export KUBECONFIG=~/.kube/aws-k8s

echo "Deploying AWS Cloud Provider using helm..."

# Verify cluster connectivity
echo "Verifying cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    echo "Please verify KUBECONFIG is correct: $KUBECONFIG"
    exit 1
fi

# Add AWS Cloud Provider Helm repository
echo "Adding AWS Cloud Provider Helm repository..."
helm repo add aws-cloud-controller-manager https://kubernetes.github.io/cloud-provider-aws 2>/dev/null || true
helm repo update

# Install or upgrade AWS Cloud Provider
echo "Installing/Upgrading AWS Cloud Provider..."
helm upgrade --install aws-cloud-controller-manager aws-cloud-controller-manager/aws-cloud-controller-manager \
  --namespace kube-system \
  --set clusterName=ic-k8slab \
  --set nodeSelector."node-role\.kubernetes\.io/control-plane"="" \
  --set tolerations[0].key=node-role.kubernetes.io/control-plane \
  --set tolerations[0].operator=Exists \
  --set tolerations[0].effect=NoSchedule \
  --set tolerations[1].key=node.cloudprovider.kubernetes.io/uninitialized \
  --set tolerations[1].operator=Exists \
  --set tolerations[1].effect=NoSchedule \
  --set args[0]=--v=2 \
  --set args[1]=--cloud-provider=aws \
  --set args[2]=--cluster-name=ic-k8slab \
  --set args[3]=--configure-cloud-routes=false

echo "AWS Cloud Provider deployed successfully!"

# Verify deployment with retry
echo "Verifying deployment..."
for i in {1..30}; do
    if kubectl get pods -n kube-system -l k8s-app=aws-cloud-controller-manager 2>/dev/null | grep -q Running; then
        echo "AWS Cloud Controller Manager is running!"
        kubectl get pods -n kube-system -l k8s-app=aws-cloud-controller-manager
        exit 0
    fi
    echo "Waiting for pods to be ready... ($i/30)"
    sleep 2
done

echo "Warning: Pods are not running yet. Check status with:"
echo "  kubectl get pods -n kube-system -l k8s-app=aws-cloud-controller-manager"
kubectl get pods -n kube-system -l k8s-app=aws-cloud-controller-manager
