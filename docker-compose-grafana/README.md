Ever wondered how to setup `varnish` and `grafana` together? If so, have a look at this minimal setup, it will set up everything need to get some graphs and dashboard on the screen.

# Getting started

- run "docker compose up -d"
- go to http://localhost:3000
- login with admin:password
- you should see the dashboard

Notes:
- check `.env` for all the variables definitions
- live logs are accessible via `docker compose logs -f`, and you can also decide which logs are shown, e.g. `docker compose logs -f origin varnishncsa load_generator` (`docker compose logs -h` for help)

Credits:
- the metrics dashboard comes from the [grafana repository](https://grafana.com/grafana/dashboards/9903-varnish/)
