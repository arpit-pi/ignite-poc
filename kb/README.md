# Knowledge base

Notes on things we learn while building this out — gotchas, how mechanisms actually work, decisions and why. Plain markdown files, one topic per file.

- [kubernetes-services.md](kubernetes-services.md) — Service `selector`/`type` gotchas we hit in `ignite/discovery.yaml` and `ignite/nodeport.yaml`.
- [local-persistent-volumes.md](local-persistent-volumes.md) — how statically-provisioned local PVs bind to StatefulSet `volumeClaimTemplates`, and how pod-to-node placement falls out of it.
- [statefulsets.md](statefulsets.md) — StatefulSet manifest gotchas: `volumeClaimTemplates` placement, `configMap` casing, `serviceName` must be the headless Service, matching `CONFIG_URI` to `mountPath`.
- [rbac.md](rbac.md) — Ignite's Kubernetes pod discovery depends on RBAC (ServiceAccount/Role/RoleBinding); a `RoleBinding` must be created in the same namespace as its `Role` or it silently grants nothing.
- [clients.md](clients.md) — thin vs thick Ignite clients, why `ignite/nodeport.yaml` only exposes REST/thin-client ports, and the recommended split for the loader (thin) and calc (thick) microservices.
