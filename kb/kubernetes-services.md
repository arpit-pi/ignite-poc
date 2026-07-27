# Kubernetes Service gotchas

Two mistakes we hit copy-pasting/writing Service manifests by hand, both in the original `ignite/discovery.yaml` and `ignite/nodeport.yaml`.

## `selector` is a flat map, not nested under `labels`

Wrong (looks natural because Pod `metadata.labels` *is* nested under a `labels` key, but Service `spec.selector` isn't):

```yaml
selector:
  labels:
    app: ignite
```

Correct:

```yaml
selector:
  app: ignite
```

`spec.selector` is matched directly against a Pod's `metadata.labels` map. Pod labels are flat key/value strings — there's no way to nest a map under one label key — so the `labels:` wrapper makes the selector look for a label literally named `labels`, which never matches. Result: the Service has zero endpoints (`kubectl get endpoints <svc>` shows `<none>`), and anything talking to it gets connection refused/timeout, with no error at `kubectl apply` time since the YAML is structurally valid.

## Headless services use `clusterIP: None`, not `type: None`

Wrong:

```yaml
spec:
  type: None
```

This fails at `kubectl apply` time with:

```
The Service "..." is invalid: spec.type: Unsupported value: "None": supported values: "ClusterIP", "ExternalName", "LoadBalancer", "NodePort"
```

Correct — leave `type` as `ClusterIP` (or omit it) and set `clusterIP: None` instead:

```yaml
spec:
  clusterIP: None
```

We need a headless service (no cluster IP, DNS returns each backing Pod's IP directly) for `ignite-discovery-service` because Ignite's `TcpDiscoveryKubernetesIpFinder` needs to enumerate individual pod IPs for its discovery SPI, not a single virtual service IP.
