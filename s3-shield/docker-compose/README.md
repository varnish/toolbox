# Deploy via docker compose

[docker compose](https://docs.docker.com/compose/) is an easy way to run pre-configured containers.

## Requirements

- `docker compose`
- you'll need to be logged into the [Varnish Enterprise docker registry](https://docs.varnish-software.com/tutorials/getting-started/varnish-enterprise-6.0/docker/) to pull the `docker` image

## Get started

First, update `s3.conf` as explained in the top [README](../README.md).

You can now start the service with:

``` bash
docker compose up
```

Your files should be accessible at http://localhost:6081/path/to/your/file.png
