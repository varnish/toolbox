This is a port of the [grafana-monitoring directory](../grafana-monitoring) using `varnish-otel` as a single [otlp](https://opentelemetry.io/docs/specs/otel/protocol/) exporter to the various `grafana` tools.
Using `opentelemetry` simplifies the process quite a bit and notably introduces tracing.

# Getting started

First, login to docker using your Varnish Enterprise Credentials. More details can be found [here in the documentation](https://docs.varnish-software.com/docker/).

- set `VARNISH_EXPERIMENTAL_TOKEN` in `.env` with your Varnish Enterprise Experimental repository token
- run "docker compose up -d"
- go to http://localhost:3000
- login with `admin:password`
- you should see the dashboard, and you can check the various data sources in the `Explore` tab

Note that by default, data is batched before being sent, so allows some time for the metrics to show up in the dashboards.

Credits:
- the metrics dashboard comes from the [grafana repository](https://grafana.com/grafana/dashboards/9903-varnish/)
