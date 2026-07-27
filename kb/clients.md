# Thin client vs thick client

Two fundamentally different ways an application talks to an Ignite cluster.

## Thick client

Joins the cluster as an actual node, just with `clientMode=true` (a "node without local data"). It participates in the same discovery (`TcpDiscoverySpi`, port `47500`) and communication (`TcpCommunicationSpi`, port `47100`) protocols as server nodes, holds a live view of cluster topology, and gets the full Ignite API — including affinity-colocated compute (`ignite.compute().affinityCall(cacheName, affinityKey, job)`, running arbitrary logic on the node that owns the data, no network hop to fetch it). Requires matching Ignite dependency/version with the server, and needs direct network reachability to every server node's discovery/communication ports — not just one address.

Cost: every thick client join/leave (pod start/restart/scale) is a topology change, which triggers a partition map exchange (PME) across the whole cluster. With persistence enabled, frequent PMEs (e.g. from a frequently-restarting/autoscaling client-mode deployment) can cause cluster-wide latency blips — this is a real operational cost, not just a connection-setup detail.

## Thin client

Doesn't join the cluster at all — just opens a socket to one address (default port `10800`) and speaks a lightweight request/response protocol (key/value get/put, SQL, and in recent Ignite versions a basic Compute API too, but without the thick client's full affinity-routing/colocation feature set). No discovery/communication ports needed, no topology participation, tiny dependency footprint, available in many languages (Java, .NET, C++, Python, Node.js).

Because it's just "connect to one socket," this is exactly what fits behind a single `NodePort`/`ClusterIP`/`LoadBalancer` Service — which is why `ignite/nodeport.yaml` only exposes `8080` (REST, no client library needed) and `10800` (thin client), not the discovery/communication ports. A thick client can't be sanely exposed through one NodePort at all, since it needs per-pod addressability to every server.

## Applied to this project's loader/calc microservices

Both services run inside the same cluster as Ignite, so (unlike an external caller going through `ignite-nodeport-service`) network reachability to discovery/communication ports isn't a blocker for either — both thin and thick are technically reachable in-cluster.

- **Loader service** (writes data in, no compute) → **thin client**. Simpler, lighter, no version lock-step requirement with the server, and — important given it's a service that will scale/restart like any other k8s deployment — it doesn't trigger topology changes/PMEs on every pod start or restart.
- **Calc service** (needs genuine colocated compute — custom logic beyond what SQL can express, executed where the data lives) → **thick client**, because affinity-colocated compute (`affinityCall`/`affinityRun`) is the thick client's core feature, giving the full API surface needed for this. Accept the PME/topology-churn cost as the tradeoff — worth checking whether Ignite 2.18's thin client Compute API happens to cover the specific colocation need before committing to thick, since that would avoid the tradeoff entirely, but thick is the standard/most complete answer for this use case.

## Why colocation still avoids network cost even though a client-mode node holds no data

Easy to misread "colocated compute" as "the calc-service process must be running on the same physical/k8s node as the data" — it doesn't. A `clientMode=true` thick client holds **zero partitions** itself, regardless of which node it's scheduled on. What `affinityCall`/`affinityRun` actually does:

1. The thick client's affinity function + cached topology tells it exactly which **server** node owns the partition for the given key.
2. It ships the **compute job** (closure/class + small parameters — not data) over the network to that one specific server node.
3. That server node executes the job **in its own process**, against its own local memory/disk — the dataset itself never leaves it.
4. Only the **result** (ideally a small aggregate/filtered value) travels back to the caller.

So two network hops still happen (job out, result back) — colocation doesn't eliminate network calls, it eliminates shipping the *raw dataset*. Code and results are typically tiny; the dataset (especially for filters/logic too complex for SQL, implying non-trivial row counts) is not. The naive alternative — pulling all relevant rows to the caller via SQL/`cache.get()` and computing client-side — transfers the full dataset every time instead.

If a single computation spans multiple partitions/nodes, Ignite still avoids bulk transfer via a MapReduce-style pattern: broadcast the job to each relevant node, each computes a partial result locally, and only the (small) partial results get shipped back to be reduced/combined.
