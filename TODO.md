# TODO

- [ ] We currently only have the headless discovery Service (`ignite/discovery.yaml`) for Ignite's own node discovery, plus a NodePort service for external/dev access (`ignite/nodeport.yaml`). We still need a ClusterIP (or LoadBalancer) Service so that in-cluster applications can talk to Ignite over the thin-client/REST ports without going through NodePort.
- [ ] `ignite/stateful.yaml` references a ConfigMap named `ignite-config` (mounted at `/ignite/config`, read via `CONFIG_URI`) that doesn't exist anywhere in the repo yet. Need to create it from `ignite/config/persistence.xml` before the StatefulSet can start.
- [ ] `ignite/stateful.yaml`'s `volumeClaimTemplates` only has `work-vol` defined so far — still need `wal-vol` and `walarchive-vol` templates (see `kb/local-persistent-volumes.md`).
