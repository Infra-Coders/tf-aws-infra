#!/bin/bash

# Quick-start script to run the Ansible Kubernetes bootstrap playbook via podman container
# Usage: ./scripts/ansible_bootstrap.sh [playbook_type] [extra_args]
#   playbook_type: basic
#   extra_args: additional ansible-playbook arguments (e.g., -v, --tags stage1)
#
# Requirements:
#   - podman installed
#   - ic-podman-ansible container image built (from podman/ansible/)
#   - Terraform outputs generated (nodes/*.json)
#   - SSH key at ssh/ic-k8slab-cluster.pem

set -uo pipefail

PLAYBOOK_TYPE="${1:-basic}"
# Forward all remaining CLI args to the podman wrapper as EXTRA_ARGS
# Example: ./scripts/ansible_bootstrap.sh basic --tags stage1 -v
shift || true
EXTRA_ARGS="${@:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBECONFIG_PATH="${SCRIPT_DIR}/.kube/aws-k8s"
PODMAN_ANSIBLE_WRAPPER="${SCRIPT_DIR}/../podman/ansible/ansible_run"

case "${PLAYBOOK_TYPE}" in
  basic)
    PLAYBOOK="bootstrap-k8s-basic.yml"
    ;;
  *)
    echo "Unknown playbook type: ${PLAYBOOK_TYPE}"
    echo "Available options at this moment: basic"
    exit 1
    ;;
esac

echo "=========================================="
echo "Kubernetes Bootstrap - Ansible (via Podman)"
echo "=========================================="
echo "Playbook: ${PLAYBOOK}"
echo "Playbook type: ${PLAYBOOK_TYPE}"
echo "Script directory: ${SCRIPT_DIR}"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v podman &> /dev/null; then
  echo "ERROR: podman not found. Please install podman."
  exit 1
fi
echo "✓ podman is available"

if [[ ! -f "${PODMAN_ANSIBLE_WRAPPER}" ]]; then
  echo "ERROR: Podman Ansible wrapper not found at ${PODMAN_ANSIBLE_WRAPPER}"
  echo "Make sure the podman/ansible directory is in the expected location"
  exit 1
fi
echo "✓ Podman Ansible wrapper found"

# Check if container image exists
if ! podman image exists localhost/ic-podman-ansible &> /dev/null; then
  echo "ERROR: Container image 'localhost/ic-podman-ansible' not found"
  echo "Build it first: cd podman/ansible && podman build -f Containerfile.amd64 -t localhost/ic-podman-ansible ."
  exit 1
fi
echo "✓ Container image available"

if [[ ! -f "${SCRIPT_DIR}/ssh/ic-k8slab-cluster.pem" ]]; then
  echo "ERROR: SSH key not found at ssh/ic-k8slab-cluster.pem"
  exit 1
fi

# Set proper permissions on SSH key
chmod 600 "${SCRIPT_DIR}/ssh/ic-k8slab-cluster.pem"
echo "✓ SSH key permissions verified"

# Check playbook exists in podman/ansible directory
PLAYBOOK_RELATIVE="podman/ansible/${PLAYBOOK}"
PLAYBOOK_PATH="${SCRIPT_DIR}/../podman/ansible/${PLAYBOOK}"

if [[ ! -f "${PLAYBOOK_PATH}" ]]; then
  echo "ERROR: Playbook not found at ${PLAYBOOK_PATH}"
  exit 1
fi
echo "✓ Playbook found: ${PLAYBOOK}"

# Create .kube directory
mkdir -p "${SCRIPT_DIR}/.kube"
echo "✓ Kubeconfig directory ready"

# Run the playbook via podman wrapper
echo ""
echo "Starting Kubernetes bootstrap via podman (${PLAYBOOK})..."
echo "=========================================="
echo ""

# Change to repo root (parent of single-master-k8s) so wrapper can find playbooks
cd "$(dirname "${SCRIPT_DIR}")"

# Export environment variables for the wrapper
export ANSIBLE_HOST_KEY_CHECKING=false
export CNI_ENGINE="${CNI_ENGINE:-calico}"

# Run ansible-playbook via podman wrapper
# The wrapper mounts ${PWD} (repo root) as /podman in the container
if "${SCRIPT_DIR}/../podman/ansible/ansible_run" "${PLAYBOOK_RELATIVE}" ${EXTRA_ARGS}; then
  echo ""
  echo "=========================================="
  echo "✓ Bootstrap completed successfully!"
  echo "=========================================="
  echo ""
  echo "To access your cluster, run:"
  echo "  export KUBECONFIG=${KUBECONFIG_PATH}"
  echo ""
  echo "Verify cluster status:"
  echo "  # Verify all nodes are ready"
  echo "  kubectl get nodes -o wide"
  echo "  kubectl get pods --all-namespaces"
  echo ""
  echo "  # Check system pods are running"
  echo "  kubectl get pods -n kube-system"
  echo ""
  echo "  # Check CNI (Calico) is deployed"
  echo "  kubectl get daemonset -n calico-system"
  echo ""
else
  echo ""
  echo "=========================================="
  echo "✗ Bootstrap failed!"
  echo "=========================================="
  exit 1
fi
