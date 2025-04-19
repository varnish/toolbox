# CMCD and CMSD integration for Varnish

## Purpose

CMCD stands for Common Media Client Data, and CMSD stands for [Common Media Server Data](https://shop.cta.tech/products/web-application-video-ecosystem-common-media-server-data-cta-5006). These are standards developed by the Consumer Technology Association (CTA) to improve video streaming performance and quality. 

This VCL leverages the two standards to achieve a few things:
- allow logging of video-specific metadata extracted from the HTTP headers of the client request
- enhance caching precision with fine-grained TLL information
- prefetch content that clients may soon needs

## Usage

Copy `cmsd-prefetch.vcl`, `cmsd-ttl.vcl`, `cmcd.vcl`, and `cmcd-cmsd.vcl` to `/etc/varnish/` and include `cmcd-cmsd.vcl` at the top of your VCL like shown below:

```
vcl 4.1;

include "cmcd-cmsd.vcl";

...
```

Note: this VCL uses Entreprise vmods (http, headerplus and urlplus), therefore you will need Varnish Enterprise to use it.

### CMCD Varnishncsa format

#### Plain text

```
varnishncsa -F "\"%{VCL_Log:cmcd-br}x\" \"%{VCL_Log:cmcd-bl}x\" \"%{VCL_Log:cmcd-bs}x\" \"%{VCL_Log:cmcd-cid}x\" \"%{VCL_Log:cmcd-d}x\" \"%{VCL_Log:cmcd-dl}x\" \"%{VCL_Log:cmcd-mtp}x\" \"%{VCL_Log:cmcd-nor}x\" \"%{VCL_Log:cmcd-nrr}x\" \"%{VCL_Log:cmcd-ot}x\" \"%{VCL_Log:cmcd-pr}x\" \"%{VCL_Log:cmcd-rtp}x\" \"%{VCL_Log:cmcd-sf}x\" \"%{VCL_Log:cmcd-sid}x\" \"%{VCL_Log:cmcd-st}x\" \"%{VCL_Log:cmcd-su}x\" \"%{VCL_Log:cmcd-tb}x\" \"%{VCL_Log:cmcd-v}x\""
```

#### JSON

```
varnishncsa -j -q "ReqUrl ~ video" -F "{\"br\": %{VCL_Log:cmcd-br}x, \"bl\": %{VCL_Log:cmcd-bl}x, \"bs\": %{VCL_Log:cmcd-bs}x, \"cid\": \"%{VCL_Log:cmcd-cid}x\", \"d\": %{VCL_Log:cmcd-d}x, \"dl\": %{VCL_Log:cmcd-dl}x, \"mtp\": %{VCL_Log:cmcd-mtp}x, \"nor\": \"%{VCL_Log:cmcd-nor}x\", \"nrr\": %{VCL_Log:cmcd-nrr}x, \"ot\": %{VCL_Log:cmcd-ot}x, \"pr\": %{VCL_Log:cmcd-pr}x, \"rtp\": %{VCL_Log:cmcd-rtp}x\", "sf": \"%{VCL_Log:cmcd-sf}x\", \"sid\": \"%{VCL_Log:cmcd-sid}x\", \"st\": \"%{VCL_Log:cmcd-st}x\", \"su\": \"%{VCL_Log:cmcd-su}x\", \"tb\": \"%{VCL_Log:cmcd-tb}x\", \"v\": %{VCL_Log:cmcd-v}x}"
```

## Tests

The `vtc`'s or Varnish Test Cases can be found under `tests`. The CMCD tests use logexpect, which will hit a timeout if the expects don't see what they are looking for in the log. It is suggested to run varnishtest with a lower timeout to avoid having to wait for the default timeout if a test fails.

A `varnishtest` can be run from command line on a machine with Varnish Enterprise by running for example:

```
varnishtest cmcd-test01.vtc
```

Note, `varnishtest` is not limited to just Enterprise, however these `vtc`'s will need to be run on an Enterprise machine as they include Enterprise only features.