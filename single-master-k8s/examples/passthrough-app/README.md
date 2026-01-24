# passthrough-app Helm Chart

⚠️ **ADVANCED USE CASE**

This chart deploys applications that terminate TLS **inside the Pod**.
Ingress only forwards encrypted traffic using **SSL passthrough**.

---

## ❗ Requirements

This chart requires:

- ingress-nginx
- ingress-nginx started with:
  ** –enable-ssl-passthrough **
- external-dns (for DNS automation)

This chart **does NOT** use:
- cert-manager
- edge TLS termination

---

## 🔐 TLS responsibility

TLS certificates are **managed by the application team**.

The application must:
- listen on HTTPS (default: 443)
- load its own certificate and private key
- handle renewals

---

## 🚀 Install example

```bash
helm install my-app ./passthrough-app \
--set ingress.host=passthrough.luke.infra-coders.com
