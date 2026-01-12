#!/bin/bash

set -uo pipefail

./scripts/tf_masters
./scripts/tf_workers

declare -A STAGE_CMD

STAGE_CMD['NODE_BOOTSTRAP']="sudo /root/scripts/check_cloud_init"
STAGE_CMD['NODE_REBOOT']="sudo shutdown -r now"
STAGE_CMD['NODE_READY']="uname -n"
STAGE_CMD['CONTROL_PLANE_BOOTSTRAP']="sudo sh /root/scripts/k8s-init.sh"
STAGE_CMD['CNI_BOOTSTRAP']="sudo sh /root/scripts/${CNI_ENGINE:-calico}-bootstrap.sh"
STAGE_CMD['KUBE_READY']="sudo bash /root/scripts/k8s-ready.sh"
STAGE_CMD['GET_WORKER_CMD_JOIN']="sudo kubeadm token create --print-join-command"
STAGE_CMD['GET_KUBECONFIG']="sudo cat /etc/kubernetes/admin.conf"

CMD_RESULT=''

run_CMD() {
  local cmd=${1}
  local cmd_timeout=${2}
  local node=${3}
  local sshcmd="aws_get -o ConnectionAttempts=${cmd_timeout}"
  local sshcmd_run="timeout --signal=INT ${cmd_timeout} ${sshcmd}"

  printf "%0.s-" {1..80}
  echo
  echo "CMD: ${cmd}"
  CMD_RESULT=$(${sshcmd_run} k8sadmin@${node} "${STAGE_CMD[${cmd}]}")
}

run_STAGE() {
  local stage=${1}
  local stage_timeout=${2}
  shift 2
  local sshcmd="aws_get -o ConnectionAttempts=${stage_timeout}"
  local sshcmd_run="timeout --signal=INT ${stage_timeout} ${sshcmd}"
  local STAGE_FAILED=0
  declare -A stage_nodes
  local node_stage_pids=()
  local node_stage_failed_pids=()

  printf "%0.s-" {1..80}
  echo
  echo "STAGE: ${stage}"

  for _node in ${@}; do
    echo "${stage} node=${_node}"
    ${sshcmd_run} k8sadmin@${_node} "${STAGE_CMD[${stage}]}" &
    node_stage_pids+=($!)
    stage_nodes[$!]="${_node}"
  done

  for _pid in ${node_stage_pids[*]}; do
    wait ${_pid} || node_stage_failed_pids+=(${_pid})
  done

  for _pid in ${node_stage_failed_pids[*]}; do
    printf "${stage} [NOK] Node=%s was not done!\n" "${stage_nodes[${_pid}]}"
    STAGE_FAILED=1
  done

  if (( ${STAGE_FAILED} == 1 )); then
    echo "STAGE: ${stage} failed!"
    return 1
  fi

  echo "STAGE: ${stage} success!"
  return 0
}

master=$(./scripts/parse_tf_output ./nodes/masters_public_ip.json | cut -d ":" -f2)
workers=$(./scripts/parse_tf_output ./nodes/workers_public_ip.json | cut -d ":" -f2)

# STAGE NODE_BOOTSTRAP
run_STAGE "NODE_BOOTSTRAP" 240 ${master} ${workers}
(( $? == 1 )) && exit 1

# STAGE NODE_REBOOT
run_STAGE "NODE_REBOOT" 60 ${master} ${workers}
(( $? == 1 )) && exit 1
sleep 60

# STAGE NODE_READY
run_STAGE "NODE_READY" 240 ${master} ${workers}
(( $? == 1 )) && exit 1


# STAGE CONTROL_PLANE_BOOTSTRAP
run_STAGE "CONTROL_PLANE_BOOTSTRAP" 600 ${master}
(( $? == 1 )) && exit 1

# STAGE CNI_BOOTSTRAP
run_STAGE "CNI_BOOTSTRAP" 240 ${master}
(( $? == 1 )) && exit 1


# CMD GET_WORKER_CMD_JOIN
run_CMD "GET_WORKER_CMD_JOIN" 60 ${master}
(( $? == 1 )) && exit 1

worker_join_cmd=${CMD_RESULT}

# STAGE DATA_PLANE_BOOTSTRAP - Use create-join-config.sh to add provider-id
STAGE_CMD['DATA_PLANE_BOOTSTRAP']="sudo /root/scripts/create-join-config.sh ${worker_join_cmd}"
run_STAGE "DATA_PLANE_BOOTSTRAP" 600 ${workers}
(( $? == 1 )) && exit 1

# STAGE KUBE_READY
run_STAGE "KUBE_READY" 300 ${master}
(( $? == 1 )) && exit 1

# CMD GET_KUBECONFIG
run_CMD "GET_KUBECONFIG" 60 ${master}
(( $? == 1 )) && exit 1

mkdir -p ~/.kube
echo "${CMD_RESULT}" > ~/.kube/aws-k8s
export KUBECONFIG=~/.kube/aws-k8s

echo "Add Workers labels"
./scripts/label_all_workers

# Wait for API server to be fully stable
echo "Waiting for API server to stabilize..."
sleep 10
for i in {1..30}; do
  if kubectl get nodes &>/dev/null; then
    echo "API server is ready"
    break
  fi
  echo "Waiting for API server... ($i/30)"
  sleep 10
done

# Deploy AWS Cloud Provider locally
echo "Deploying AWS Cloud Provider locally..."
export KUBECONFIG=~/.kube/aws-k8s
./scripts/deploy-aws-cloud-provider.sh || {
  echo "Warning: AWS Cloud Provider deployment failed. You can retry manually with:"
  echo "  export KUBECONFIG=~/.kube/aws-k8s"
  echo "  ./scripts/deploy-aws-cloud-provider.sh"
}

# Patch CoreDNS to use Google DNS (prevents VPC DNS caching issues for cert-manager)
echo "Patching CoreDNS to use Google DNS..."
kubectl apply -f manifests/coredns-patch.yaml 2>/dev/null || true
kubectl rollout restart deployment coredns -n kube-system 2>/dev/null || true

printf "%0.s*" {1..80}
echo
echo "export KUBECONFIG=~/.kube/aws-k8s"
printf "%0.s*" {1..80}
echo
