# Statically-provisioned local PVs with StatefulSet volumeClaimTemplates

Context: `ignite/volumes.yaml` defines PersistentVolumes by hand (no dynamic provisioner — `cluster-resources/storage.yaml` uses `provisioner: kubernetes.io/no-provisioner`), one triplet (`work`, `wal`, `walarchive`) per worker node, each pinned via `spec.nodeAffinity` to a specific `kubernetes.io/hostname`. The Ignite StatefulSet uses `volumeClaimTemplates` rather than hand-written PVCs. Notes on how these two things actually connect.

## You don't create the PVCs by hand

Each entry in `volumeClaimTemplates` generates one PVC **per replica**, named `<template-name>-<statefulset-name>-<ordinal>` in the StatefulSet's namespace. E.g. with 3 templates (`work-vol`, `wal-vol`, `walarchive-vol`) and `replicas: N`, you get `3 * N` PVCs total — not something you author directly. To match 9 PVs (3 per node × 3 nodes) you need `replicas: 3`, not 9 of anything in the manifest itself.

`storageClassName` in each template should be set explicitly to `local-storage` (matching `cluster-resources/storage.yaml`) even though it happens to be the default class — don't rely on the implicit default assignment.

## Why no `nodeSelector` is needed for correct placement

`cluster-resources/storage.yaml` sets `volumeBindingMode: WaitForFirstConsumer`, which defers PVC-to-PV binding until a pod that uses the PVC is actually being scheduled. At that point the scheduler's volume-binding plugin looks for a single node where **all** of that pod's pending PVCs can be satisfied simultaneously from `Available` PVs of the right class, treating each candidate PV's `nodeAffinity` as a hard constraint on the pod.

Since each node has exactly one PV per template (one work, one wal, one walarchive), this resolves unambiguously per node — there's no meaningful "wrong" PV to bind to, since the underlying volume is just empty local storage until Ignite writes to it (the `volumeMounts.mountPath` in the pod spec, not the PV's name, is what gives a directory its role). Whichever node hosts ordinal-0's pod first, it claims that node's full triplet; ordinal-1 is then forced onto a different node since the first node's PVs are already claimed. StatefulSets default to `podManagementPolicy: OrderedReady` (create pods one at a time, wait for Running before the next), so there's no race between ordinals for the same node's PVs.

Net effect: the PVs' own `nodeAffinity` fields are what pin pods to nodes. An explicit `nodeSelector` on the pod template is redundant for this purpose.

## `claimRef` pre-binding, if you want a deterministic (not race-based) mapping

If you want ordinal-0 to *always* land on `worker-node-1` rather than "whichever node wins the scheduling race," pre-bind each PV to its expected PVC name/namespace:

```yaml
spec:
  claimRef:
    namespace: ignite
    name: work-vol-ignite-cluster-0
```

Add this to each PV, computing the deterministic PVC name from `<template-name>-<statefulset-name>-<ordinal>` for the ordinal that maps to that PV's node. Not yet applied in this repo — the current setup uses the race-resolves-correctly-by-construction behavior described above.
