# Standalone OpenTelemetry & Grafana setup
This `docker compose` example contains a standalone observability stack for [OpenTelemetry](https://opentelemetry.io/) ingestion, storage and visualization with [Grafana](https://grafana.com/).

It is intended as a drop-in backend you can point any OTLP-emitting workload at. It runs on the same Docker host, in another container, or on your computer without bringing along an application of its own. If you want a worked example wired up to Varnish, see [grafana-monitoring-otel](../grafana-monitoring-otel/) instead.

## Components

The stack is composed of five services, all attached to a shared `observability` bridge network:

- **[OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)** (`otel-collector`) — receives OTLP metrics, logs and traces from your workloads and fans them out to the right backend.
- **[Prometheus](https://prometheus.io/)** (`prometheus`) — stores metrics. The native OTLP receiver and remote-write receiver are both enabled, so the collector can push metrics directly via OTLP.
- **[Loki](https://grafana.com/oss/loki/)** (`loki`) — stores logs. Configured with the native OTLP receiver and indexes `service.name`, `service.namespace` and `deployment.environment` resource attributes as labels.
- **[Tempo](https://grafana.com/oss/tempo/)** (`tempo`) — stores traces. The metrics generator is enabled to derive service graphs and span metrics, which are remote-written to Prometheus.
- **[Grafana](https://grafana.com/)** (`grafana`) — visualization. Anonymous access is enabled with `Admin` role, so no login is required. Datasources for Prometheus, Loki and Tempo are pre-provisioned, including trace ↔ log ↔ metric correlation.

The data flow looks like this:

```
your app ──OTLP──▶ otel-collector ──┬──▶ prometheus  (metrics)
                                    ├──▶ loki        (logs)
                                    └──▶ tempo       (traces)
                                                        │
                                                        ▼
                                                     grafana
```

## Spinning it up

From this directory:

```sh
docker compose up -d
```

Once the containers are healthy, open Grafana at [http://localhost:3000](http://localhost:3000). No credentials are needed, and anonymous access is granted with admin privileges. The Prometheus, Loki and Tempo datasources are already configured under **Connections → Data sources**, and you can use the **Explore** tab to query each backend.

## Tearing it down

To stop the stack while keeping container state:

```sh
docker compose stop
```

To remove the containers and the network:

```sh
docker compose down
```

Note that this stack uses ephemeral in-container storage (no named volumes are declared), so all metrics, logs and traces are wiped when the containers are removed.

## Dashboards
### Pre-provisioned Varnish dashboard

Even though the stack itself does not run Varnish, a ready-made dashboard for debugging a running Varnish instance is shipped in [conf/grafana/dashboards/varnish.json](conf/grafana/dashboards/varnish.json) and provisioned automatically into Grafana. It shows up as **Varnish metrics** in the dashboard list — described as *"A dashboard to use to debug a running Varnish instance."*

It is built on Prometheus metrics emitted by [`varnish-otel`](https://docs.varnish-software.com/varnish-otel/) (or any equivalent Varnish OTLP exporter) flowing through this stack's OTel Collector, and is organized into rows that cover the operational concerns you typically care about when triaging Varnish:

- **Overview** — instance count, current serving rate, traffic offload, backend health, MSE4 stores online and panic counter.
- **Traffic** — data transfer per second, new connections and requests, offload rate, cache invalidation requests and objects invalidated.
- **Errors** — sick backends, session failures, backend errors, stale responses, MSE4 offline books/stores, brotli and other miscellaneous errors.
- **Saturation** — objects in cache, objects evicted or expired, ykey counts and iteration latency, memory governor, threads.
- **Latency** — request and backend latency distributions.
- **Virtual Registry & Artifact Accounting** — bandwidth, requests and cache hit rate broken down by virtual registry and artifact type (useful when fronting a registry-style workload).

To open it, click the **Dashboards** icon in the left-hand Grafana sidebar and pick **Varnish metrics** from the list (it is provisioned at the root level, so no folder navigation is needed). The panels stay empty until something is actually pushing Varnish metrics into the collector — point your Varnish instance's OTLP exporter at the collector using one of the connection options described below.

### Adding your own dashboards

The whole [conf/grafana/dashboards/](conf/grafana/dashboards/) directory is mounted read-only into the Grafana container at `/var/lib/grafana/dashboards`, and the file provider is configured with `foldersFromFilesStructure: true` and a 10-second `updateIntervalSeconds`. To add your own dashboards:

1. Drop a Grafana-exported JSON file (for example `my-dashboard.json`) into [conf/grafana/dashboards/](conf/grafana/dashboards/) next to `varnish.json`. Subdirectories become Grafana folders, so `conf/grafana/dashboards/team-a/foo.json` lands under a **team-a** folder in the UI.
2. Wait up to ten seconds — Grafana picks up new and changed files on disk automatically, so there's no need to restart the container.
3. Refresh the **Dashboards** view; the new dashboard appears in the list.

If you exported the dashboard from another Grafana instance, make sure its panels reference the datasource UIDs provisioned here (`prometheus`, `loki`, `tempo`) — otherwise they will show "Datasource not found" until you remap them. Because `allowUiUpdates: true` is set, you can also tweak dashboards interactively in Grafana and then use **Share → Export → Save to file** to write the result back into [conf/grafana/dashboards/](conf/grafana/dashboards/).

## Connecting to the stack

### From the host (`localhost`)

The following ports are published to the Docker host:

| Service        | Endpoint                                                       | Purpose                  |
| -------------- | -------------------------------------------------------------- | ------------------------ |
| Grafana        | [http://localhost:3000](http://localhost:3000)                 | UI                       |
| OTel Collector | `http://localhost:4318`                                        | OTLP/HTTP receiver       |
| OTel Collector | `localhost:4317`                                               | OTLP/gRPC receiver       |
| OTel Collector | [http://localhost:8888/metrics](http://localhost:8888/metrics) | Collector self-metrics   |
| Prometheus     | [http://localhost:9090](http://localhost:9090)                 | Prometheus UI / API      |
| Loki           | [http://localhost:3100](http://localhost:3100)                 | Loki HTTP API            |
| Tempo          | [http://localhost:3200](http://localhost:3200)                 | Tempo HTTP API           |

Point an OTLP exporter on your host machine at the collector with, for example:

```sh
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

### From another container (`host.docker.internal`)

If your workload runs in a container that is **not** part of this compose project (for example, a separate `docker compose` stack or a one-off `docker run`), it cannot resolve `otel-collector` or `grafana` directly because it is on a different Docker network. Use `host.docker.internal` to reach the published ports on the host:

```sh
export OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

The same hostname applies to Grafana ([http://host.docker.internal:3000](http://host.docker.internal:3000)) and to direct queries against Prometheus, Loki or Tempo.

On Docker Desktop (macOS and Windows) `host.docker.internal` is available out of the box. On Linux, add this to the workload's service definition so the hostname resolves to the host gateway:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

### From a container on the same compose network

If you extend this `compose.yaml` (or attach another compose project to the `observability` network), services can address each other by container name on the internal ports:

- `http://otel-collector:4318` (OTLP/HTTP)
- `otel-collector:4317` (OTLP/gRPC)
- `http://grafana:3000`
- `http://prometheus:9090`
- `http://loki:3100`
- `http://tempo:3200`
