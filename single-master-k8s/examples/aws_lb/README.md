# AWS Load Balancer Controller (ALB) Example

This directory contains a minimal example that provisions an **AWS Application Load Balancer (ALB)** using the **AWS Load Balancer Controller**.

## Prerequisites

- AWS Load Balancer Controller installed in the cluster
- IAM permissions for the controller (already covered by this repo’s AWS LB policy)

## Deploy

```bash
kubectl apply -f deployment_echo.yaml
kubectl apply -f svc_echo.yaml
kubectl apply -f ingress_ALB.yaml
```

## Verify

```bash
kubectl get pods
kubectl get svc echo
kubectl get ingress echo-alb
```

Wait a few minutes until `.status.loadBalancer` is populated.

## Cleanup

```bash
kubectl delete -f ingress_ALB.yaml
kubectl delete -f svc_echo.yaml
kubectl delete -f deployment_echo.yaml
```
