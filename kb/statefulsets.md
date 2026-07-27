# StatefulSet gotchas (from reviewing `ignite/stateful.yaml`)

## `volumeClaimTemplates` is a `StatefulSetSpec` field, not a `PodSpec` field

It must be indented as a sibling of `template:`, directly under the StatefulSet's own `spec:` — not nested inside `template.spec` (the pod spec) alongside `containers`/`volumes`/`securityContext`. Easy to get wrong since it visually reads like it belongs with the other volume-related fields in the pod spec, but the pod spec has no such field — `kubectl apply` will reject it there.

```yaml
spec:                     # StatefulSetSpec
  replicas: 3
  serviceName: ...
  selector: {...}
  template:                # PodTemplateSpec
    spec:                    # PodSpec — containers, volumes, securityContext live here
      ...
  volumeClaimTemplates:    # ← sibling of `template`, NOT inside template.spec
  - metadata: {...}
```

## `configMap` is camelCase

`volumes[].configmap` (lowercase `m`) fails schema validation — the field is `configMap`.

## `serviceName` must be the *headless* Service, specifically

A StatefulSet's `serviceName` field designates which Service provides stable per-pod DNS identity (`<pod>.<serviceName>.<namespace>.svc.cluster.local`). It must point at a Service with `clusterIP: None` — a regular ClusterIP/NodePort Service won't give each pod its own DNS record.

In this repo that's `ignite-discovery-service` (`ignite/discovery.yaml`), not `ignite-nodeport-service`. Having multiple Services select the same pods is completely normal and not a conflict — `ignite-nodeport-service` also targets `app: ignite` pods for external access via NodePort, and doesn't need to be referenced anywhere in the StatefulSet manifest at all. It works purely off its label selector once pods exist. `serviceName` is *only* about which Service governs pod DNS identity, not about "which Service owns these pods."

## Match `CONFIG_URI` (or any file-path env var) to the actual `mountPath`

Easy copy-paste mismatch: if `volumeMounts` mounts the config volume at `/ignite/config`, an env var like `CONFIG_URI: file:///config/persistence.xml` (missing the `/ignite` prefix) will point at a path that doesn't exist in the container. No validation catches this — it only surfaces as a runtime error in the container logs.

## A referenced ConfigMap must actually exist somewhere

`volumes[].configMap.name: ignite-config` only works if a `ConfigMap` named `ignite-config` exists in the same namespace — nothing in the StatefulSet manifest creates it. Needs its own manifest (or `kubectl create configmap --from-file=...`) sourced from `ignite/config/persistence.xml`, applied before/alongside the StatefulSet.
