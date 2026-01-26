# Edge App Helm Chart

A simple Helm chart for exposing HTTP applications behind **ingress-nginx**
with **edge TLS termination**, **cert-manager**, and **external-dns**.

The chart is **infrastructure-agnostic** and works with a **central NLB**,
regardless of whether the NLB is managed by:
- AWS Cloud Provider, or
- AWS Load Balancer Controller

---

## 🧱 What this chart does

When installed, this chart:

- deploys the application (`Deployment`)
- exposes it as a `ClusterIP` `Service`
- creates an `Ingress` (`ingress-nginx`)
- automatically:
  - creates DNS records (external-dns)
  - issues TLS certificates (cert-manager)
  - terminates TLS at the ingress

**TLS is terminated at the Ingress**  
Traffic from Ingress → Pod is **unencrypted (HTTP)**.

---

## 📋 Prerequisites (must already exist)

The platform must already provide:

- ingress-nginx (`IngressClass: nginx`)
- cert-manager
- a `ClusterIssuer`:
  - `letsencrypt-staging` or
  - `letsencrypt-prod`
- external-dns
- a **central NLB** pointing to ingress-nginx

> If you’re unsure whether this is ready, contact the platform team.

---

## 🚀 Quick start (most common case)

Each team deploys its app under its **own subdomain** in `infra-coders.com`.

### Example: `edge.luke.infra-coders.com`

```bash
helm install luke-edge ./edge-app \
  --set ingress.host=edge.luke.infra-coders.com
