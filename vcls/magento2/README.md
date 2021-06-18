# Enterprise VCLfor Magento2

[Magento2](https://github.com/magento/magento2) already provides an open-source
Varnish VCL to boost the performance of this CMS. This VCL builds and
extends on it to enable Varnish Enterprise features that are not available in
the open-source version, notably:

- faster and more efficien purging thanks to [`ykey`](https://docs.varnish-software.com/varnish-cache-plus/vmods/ykey/)
- DNS-based backends using [`goto`](https://docs.varnish-software.com/varnish-cache-plus/vmods/goto/), making it easier
  to vuild an independent caching cluster in fron of the Magento2 layer
- cleaner and more efficient code

To leverage this you will need to replace the `default.vcl` template provided by
Magento2 with the one in this directory, then generate the VCL with Magento2
as you usually would.

## Varnish version

The only version targeted is Varnish Plus 6.0.

## Tests

To test on a machine where Varnish Plus is installed, you can run

``` bash
varnishtest *.vtc
```

Otherwise, you can use `bob` (at the root of this repository) to build a
`docker` image for you (you will need access to the Varnish Enterprise registry):

``` bash
bob varnishtest *.vtc
```
