# ingress-nginx with Central NLB (AWS)

This directory documents **two supported deployment models** for running
**ingress-nginx behind a central AWS Network Load Balancer (NLB)** in a
**self-managed Kubernetes cluster on AWS**.

Both models expose **the same ingress interface to application teams**.
The difference lies entirely in **how the NLB is created, owned, and managed**
by the platform.

---

## High-level overview

| Model | NLB Owner | ingress-nginx Service | Recommended |
|------|----------|----------------------|-------------|
| AWS Cloud Provider + NLB | cloud-provider-aws | LoadBalancer | ❌ Legacy |
| AWS Load Balancer Controller + NLB | AWS LB Controller | NodePort + central Service | ✅ Yes |

From an **application perspective**:
- Ingress manifests are identical
- cert-manager works the same
- external-dns works the same
- TLS behavior is the same

---

# Model 1: AWS Cloud Provider + Central NLB

**Path:** aws_cloud_provider_NLB/

## Description

In this model, the **AWS cloud provider integration** creates and manages
the Network Load Balancer directly from the `ingress-nginx` Service
of type `LoadBalancer`.

This is the **simplest setup**, but relies on legacy cloud-provider behavior
and tighter coupling between Kubernetes and AWS.

---

## ingress-nginx configuration

```yaml
controller:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

---

## Component flow (TXT)

```
Internet
  ↓
AWS NLB
  ↓
Service (LoadBalancer)
  ↓
ingress-nginx
  ↓
Ingress (nginx)
  ↓
Service (ClusterIP)
  ↓
Pod
```

---

## Pros / Cons

**Pros**
- simple and fast to set up
- fewer moving parts

**Cons**
- legacy cloud-provider dependency
- harder to evolve (IRSA, fine-grained IAM)

---

# Model 2: AWS Load Balancer Controller + Central NLB (Recommended)

**Path:** aws_lb_controller_NLB/

## Description

In this model, the **AWS Load Balancer Controller** creates and manages
the Network Load Balancer.

`ingress-nginx` runs behind a deterministic **NodePort Service** and is
decoupled from AWS infrastructure concerns.

In this repo, the **central NLB Service** (`ingress-nlb`) is the one that owns
the fixed NodePorts (31080/31443).

---

## ingress-nginx configuration (ClusterIP)

```yaml
controller:
  publishService:
    enabled: true
    pathOverride: ingress-nginx/ingress-nlb
  service:
    type: ClusterIP
```

---

## Central NLB Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ingress-nlb
spec:
  type: LoadBalancer
  ports:
    - name: http
      port: 80
      nodePort: 31080
      targetPort: 80
    - name: https
      port: 443
      nodePort: 31443
      targetPort: 443
```

---

## Component flow (TXT)

```
Internet
  ↓
AWS NLB (AWS LB Controller)
  ↓
Service ingress-nlb (LoadBalancer)
  ↓
NodePort (31080 / 31443)
  ↓
ingress-nginx
  ↓
Ingress (nginx)
  ↓
Service (ClusterIP)
  ↓
Pod
```

---

## Platform recommendation

Use **AWS Load Balancer Controller + Central NLB** as the default model.

Applications should only interact with **Ingress**.
Load Balancers are a platform implementation detail.

## Notes

In the central NLB model, the NLB hostname lives on the `ingress-nlb` Service.
If you use `external-dns` with `--source=ingress`, ensure `ingress-nginx` is
configured to publish Ingress status from that Service (`controller.publishService`).

For `cert-manager` HTTP-01 challenges, the ACME server must be able to reach
port 80 on the same hostname used for the Ingress.
