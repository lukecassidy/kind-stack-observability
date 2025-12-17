# kind-stack-observability
A local Kubernetes **observability stack** running on a **kind** cluster.

Built for **development and learning**. Quick to spin up, quick to tear down.

---

## Quickstart (TL;DR)
```bash
make kind-up      # create cluster
make deploy       # validate and deploy stack
make health-check # verify everything is running
make pf-all       # port-forward all UIs
```

Open:
- Prometheus -> [http://localhost:9090](http://localhost:9090)
- Alertmanager -> [http://localhost:9093](http://localhost:9093)
- Grafana -> [http://localhost:3000](http://localhost:3000) (admin/admin)
- OpenSearch Dashboards -> [http://localhost:5601](http://localhost:5601)
- Jaeger UI -> [http://localhost:16686](http://localhost:16686)
- podinfo-frontend -> [http://localhost:8080](http://localhost:8080)
- podinfo-backend -> [http://localhost:8081](http://localhost:8081)

---

## Prerequisites
- Docker
- kind
- kubectl
- helm
- helmfile

Configure Docker Desktop with at least 8GB memory for things to run smoothly.

---

## Defaults (Ports, Auth, Namespaces)

| Component             | Namespace     | URL / Port                                       | Auth          | Notes                         |
| --------------------- | ------------- | ------------------------------------------------ | ------------- | ----------------------------- |
| Prometheus            | observability | [http://localhost:9090](http://localhost:9090)   | none          | no persistence, sample alerts |
| Alertmanager          | observability | [http://localhost:9093](http://localhost:9093)   | none          | no persistence                |
| Grafana               | observability | [http://localhost:3000](http://localhost:3000)   | admin / admin | no persistence                |
| OpenSearch API        | observability | [http://localhost:9200](http://localhost:9200)   | none          | security disabled             |
| OpenSearch Dashboards | observability | [http://localhost:5601](http://localhost:5601)   | none          | security disabled             |
| Jaeger UI             | observability | [http://localhost:16686](http://localhost:16686) | none          | no persistence                |
| Podinfo Frontend      | demo          | [http://localhost:8080](http://localhost:8080)   | none          | web UI, `/api/echo` endpoint  |
| Podinfo Backend       | demo          | [http://localhost:8081](http://localhost:8081)   | none          | backend echo service          |

Deployment is handled by Helm via Helmfile, with make commands simplifying all operations.

---

## Architecture
```mermaid
flowchart LR
    subgraph Kind Cluster
        subgraph Observability Namespace
            P[Prometheus]
            G[Grafana]
            OS[OpenSearch]
            OSD[OpenSearch Dashboards]
            J[Jaeger]
            FB[Fluent Bit]
        end

        subgraph Demo Namespace
            PIF[podinfo-frontend]
            PIB[podinfo-backend]
        end

        PIF -->|/api/echo| PIB
        PIF -->|metrics| P
        PIB -->|metrics| P
        PIF -->|traces| J
        PIB -->|traces| J
        PIF -->|logs| FB --> OS --> OSD
        PIB -->|logs| FB
        G -->|dashboards| P
    end
```

---

## Sample App: podinfo
[podinfo](https://github.com/stefanprodan/podinfo) lives in the `demo` namespace and produces both logs and metrics for testing.
- **podinfo-frontend** (port 8080) - Frontend service with web UI
- **podinfo-backend** (port 8081) - Backend service for echo requests

Key Endpoints:
  - `/` - Web UI
  - `/healthz` - Health check
  - `/readyz` - Readiness check
  - `/metrics` - Prometheus metrics
  - `/api/echo` - Test frontend to backend communication
  - `/env`, `/headers` - Debugging info


Test that the frontend can successfully communicate with the backend.

```bash
curl -X POST http://localhost:8080/api/echo -d '{"test":"frontend-to-backend"}'

Expected response:
[
  "{\"test\":\"frontend-to-backend\"}"
]
```

---

## Verify Observability

Generate traffic to test the stack:
```bash
for i in {1..10}; do curl -s localhost:8080/ > /dev/null; done
```

**Metrics** - Prometheus ([http://localhost:9090](http://localhost:9090))
```text
Query: http_requests_total{app="podinfo"}
```

**Dashboards** - Grafana ([http://localhost:3000](http://localhost:3000))
```text
Query: rate(http_requests_total{app="podinfo"}[1m])
```

**Logs** - OpenSearch Dashboards ([http://localhost:5601](http://localhost:5601))
```text
Discover -> Index: kubernetes-logs* -> Filter: kubernetes.namespace_name:"demo"
```

**Traces** - Jaeger UI ([http://localhost:16686](http://localhost:16686))
```text
Service: podinfo-frontend or podinfo-backend -> Find Traces
```

**Alerts** - Alertmanager ([http://localhost:9093](http://localhost:9093))
```text
View active alerts, silences, and alert groups
Alerts -> Shows all firing and pending alerts
```

---

## Resource Sizing

All components are configured with **minimal resource limits** suitable for local development:

| Component               | CPU Request | Memory Request | CPU Limit | Memory Limit | Rationale                                  |
| ----------------------- | ----------- | -------------- | --------- | ------------ | ------------------------------------------ |
| Prometheus              | 100m        | 256Mi          | 500m      | 512Mi        | Scrapes ~10 targets, no persistence        |
| Grafana                 | 100m        | 128Mi          | 500m      | 256Mi        | Serves 4 dashboards, no persistence        |
| OpenSearch              | 1000m       | 512Mi          | 2000m     | 1Gi          | Single node with 5Gi storage, handles logs |
| OpenSearch Dashboards   | 100m        | 256Mi          | 500m      | 512Mi        | Query UI only, minimal processing          |
| Jaeger                  | 100m        | 256Mi          | 500m      | 512Mi        | All-in-one mode, in-memory traces          |
| Fluent Bit              | 100m        | 128Mi          | 500m      | 256Mi        | DaemonSet log collector, minimal overhead  |
| podinfo (frontend/back) | 10m         | 32Mi           | 100m      | 64Mi         | Lightweight demo apps                      |

**Total cluster requirements**: ~2-3 vCPU, ~3-4Gi memory minimum.
**Recommended Docker Desktop allocation: 8GB** for smooth operation and overhead.

---

## Troubleshooting
- **Port conflicts**: `make pf-stop` or `lsof -ti:9090 | xargs kill -9`
- **Pods failing**: `kubectl get pods -A` and `kubectl describe pod <name> -n <namespace>`.
- **Deployment issues**: Run `make validate` then `helmfile -l name=<component> apply`
- **Can't access services**: Restart port-forwards with `make pf-stop && make pf-all`
- **Get logs**: `kubectl logs -n observability deployment/<component> --tail=20`
- **Check health**: `./scripts/health-check.sh` or `curl http://localhost:9090/api/v1/targets`

---

## Tear Down
```bash
make destroy    # remove Helm releases
make kind-down  # delete the kind cluster
```

---

## Notes
- OpenSearch is single node and unsecured (dev only).
- Fluent Bit forwards all container logs to OpenSearch.
- Jaeger uses all-in-one deployment with no persistence.
- podinfo pods are for validating end to end observability.
- Prometheus and Grafana have no persistence to support an ephemeral workflow.
- The stack is intended for short lived, iterative demo environments.


