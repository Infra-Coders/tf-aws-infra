Flux deployment
---------------

### Install via helm

> Install helm
```
> curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | sudo bash
```

> Install Flux Operator
[flux install](https://fluxcd.io/flux/installation/#install-the-flux-operator)
```
> helm install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator --namespace flux-system --create-namespace
```

> Create FluxIntance Custom Resource
[fluxinstance](https://fluxcd.control-plane.io/operator/fluxinstance/)
```
> kubectl apply -f ./fluxinstance.yaml
```
