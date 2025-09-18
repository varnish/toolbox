This is a port of the [grafana-monitoring directory](../grafana-monitoring) using `varnish-otel` as a single [otlp](https://opentelemetry.io/docs/specs/otel/protocol/) exporter to the various `grafana` tools.
Using `opentelemetry` simplifies the process quite a bit and notably introduces tracing.

# Getting started

- place the license file ( `varnish-enterprise.lic`, you can ask for one [here](https://www.varnish-software.com/contact-us/))
- run "docker compose up -d"
- go to http://localhost:3000
- login with `admin:password`
- you should see the dashboard, and you can check the various data sources in the `Explore` tab


Credits:
- the metrics dashboard comes from the [grafana repository](https://grafana.com/grafana/dashboards/9903-varnish/)
