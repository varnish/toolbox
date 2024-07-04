# Deploying via helm

[helm](https://helm.sh/) allows `kubernetes` users to deploy services with prepackaged "charts".

## Requirements

`helm` is of course required for this, and you'll need to configure it to use the [Varnish Enterprise charts](https://docs.varnish-software.com/varnish-helm/guides/setting-up-repository/)

## Getting started

First, update `s3.conf` as explained in the top [README](../README.md).

Next, push the VCL as a `configmap` and `s3.conf` as a secret:

``` bash
kubectl create configmap varnish-s3-vcl --from-file=../default.vcl
kubectl create secret generic varnish-s3-conf --from-file=./s3.conf
```

The chart can now be deployed:

``` bash
helm install -f values.yaml varnish-enterprise varnish/varnish-enterprise
```
