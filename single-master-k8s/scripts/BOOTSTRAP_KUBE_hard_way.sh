#!/bin/bash

echo "Kubernetes init ControlPlane"
master=$(./scripts/parse_tf_output ./nodes/masters_public_ip.json | cut -d ":" -f2)
./scripts/aws_get ${master} "sudo sh /root/scripts/k8s-init.sh"

echo "Kubernetes adding Workers"
worker_join_cmd=$(./scripts/aws_get ${master} < ./scripts/get_worker_token_cmd)
for w in $(./scripts/parse_tf_output ./nodes/workers_public_ip.json | cut -d ":" -f2); do ./scripts/aws_get $w "sudo ${worker_join_cmd}"; done 

echo "Configure local kubeconf"
./scripts/aws_get ${master} < ./scripts/get_kubeconf > ~/.kube/aws-k8s
export KUBECONFIG=~/.kube/aws-k8s

echo "Add Workers labels"
./scripts/label_all_workers
