#!/bin/bash

# macOS ships bash 3.x (no associative arrays), so keep the script POSIX-friendly.
set -uo pipefail

./scripts/tf_masters
./scripts/tf_workers

CMD_RESULT=""

get_stage_cmd() {
  case "$1" in
    NODE_BOOTSTRAP) echo "sudo /root/scripts/check_cloud_init" ;;
    NODE_REBOOT) echo "sudo shutdown -r now" ;;
    NODE_READY) echo "uname -n" ;;
    CONTROL_PLANE_BOOTSTRAP) echo "sudo sh /root/scripts/k8s-init.sh" ;;
    GET_WORKER_CMD_JOIN) echo "sudo kubeadm token create --print-join-command" ;;
    GET_KUBECONFIG) echo "sudo cat /etc/kubernetes/admin.conf" ;;
    DATA_PLANE_BOOTSTRAP) echo "sudo ${2:-}" ;; # worker join command provided at runtime
    *) return 1 ;;
  esac
}

pick_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    echo "timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    echo "gtimeout"
  else
    echo ""
  fi
}

run_CMD() {
  local cmd="$1"
  local cmd_timeout="$2"
  local node="$3"
  local stage_cmd

  stage_cmd=$(get_stage_cmd "${cmd}") || return 1

   local timeout_bin
   timeout_bin=$(pick_timeout)

  local sshcmd="ssh -T -o StrictHostKeyChecking=no -o ConnectionAttempts=${cmd_timeout} -i ssh/ic-k8slab-cluster.pem"
  local sshcmd_run="${sshcmd}"

  if [[ -n "${timeout_bin}" ]]; then
    sshcmd_run="${timeout_bin} --signal=INT ${cmd_timeout} ${sshcmd}"
  else
    echo "Warning: timeout/gtimeout not found; commands will not be force-stopped after ${cmd_timeout}s."
  fi

  printf "%0.s-" {1..80}
  echo
  echo "CMD: ${cmd}"
  CMD_RESULT=$(${sshcmd_run} k8sadmin@${node} "${stage_cmd}")
}

run_STAGE() {
  local stage="$1"
  local stage_timeout="$2"
  local join_cmd="${3:-}"
  shift 3 || true

  local stage_cmd
  stage_cmd=$(get_stage_cmd "${stage}" "${join_cmd}") || return 1

  local timeout_bin
  timeout_bin=$(pick_timeout)

  local sshcmd="ssh -T -o StrictHostKeyChecking=no -o ConnectionAttempts=${stage_timeout} -i ssh/ic-k8slab-cluster.pem"
  local sshcmd_run="${sshcmd}"

  if [[ -n "${timeout_bin}" ]]; then
    sshcmd_run="${timeout_bin} --signal=INT ${stage_timeout} ${sshcmd}"
  else
    echo "Warning: timeout/gtimeout not found; commands will not be force-stopped after ${stage_timeout}s."
  fi
  local STAGE_FAILED=0
  local node_stage_pids=()
  local node_stage_nodes=()
  local idx=0

  printf "%0.s-" {1..80}
  echo
  echo "STAGE: ${stage}"

  for _node in "$@"; do
    echo "${stage} node=${_node}"
    ${sshcmd_run} k8sadmin@${_node} "${stage_cmd}" &
    node_stage_pids[${idx}]=$!
    node_stage_nodes[${idx}]="${_node}"
    idx=$((idx+1))
  done

  for i in "${!node_stage_pids[@]}"; do
    wait "${node_stage_pids[$i]}" || {
      printf "%s [NOK] Node=%s was not done!\n" "${stage}" "${node_stage_nodes[$i]}"
      STAGE_FAILED=1
    }
  done

  if (( STAGE_FAILED == 1 )); then
    echo "STAGE: ${stage} failed!"
    return 1
  fi

  echo "STAGE: ${stage} success!"
  return 0
}

master=$(./scripts/parse_tf_output ./nodes/masters_public_ip.json | cut -d ":" -f2)
workers=$(./scripts/parse_tf_output ./nodes/workers_public_ip.json | cut -d ":" -f2)

# STAGE NODE_BOOTSTRAP
run_STAGE "NODE_BOOTSTRAP" 240 "" ${master} ${workers}
(( $? == 1 )) && exit 1

# STAGE NODE_REBOOT
run_STAGE "NODE_REBOOT" 60 "" ${master} ${workers}
(( $? == 1 )) && exit 1
sleep 60

# STAGE NODE_READY
run_STAGE "NODE_READY" 300 "" ${master} ${workers}
(( $? == 1 )) && exit 1

# STAGE CONTROL_PLANE_BOOTSTRAP
run_STAGE "CONTROL_PLANE_BOOTSTRAP" 600 "" ${master}
(( $? == 1 )) && exit 1

# CMD GET_WORKER_CMD_JOIN
run_CMD "GET_WORKER_CMD_JOIN" 60 ${master}
(( $? == 1 )) && exit 1

worker_join_cmd="${CMD_RESULT}"

# STAGE DATA_PLANE_BOOTSTRAP
run_STAGE "DATA_PLANE_BOOTSTRAP" 600 "${worker_join_cmd}" ${workers}
(( $? == 1 )) && exit 1

# CMD GET_KUBECONFIG
run_CMD "GET_KUBECONFIG" 60 ${master}
(( $? == 1 )) && exit 1

mkdir -p ~/.kube
echo "${CMD_RESULT}" > ~/.kube/aws-k8s
export KUBECONFIG=~/.kube/aws-k8s

echo "Add Workers labels"
./scripts/label_all_workers

echo ""
echo "Please export KUBECONFIG before using kubectl:"
echo "export KUBECONFIG=\$HOME/.kube/aws-k8s"
