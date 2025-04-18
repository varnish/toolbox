# CMCD and CMSD integration for Varnish

## Purpose

CMCD stands for Common Media Client Data, and CMSD stands for [Common Media Server Data](https://shop.cta.tech/products/web-application-video-ecosystem-common-media-server-data-cta-5006). These are standards developed by the Consumer Technology Association (CTA) to improve video streaming performance and quality. 

The vcl serves two do two things:

- First, regarding CMCD, this VCL will look for the CMCD request headers (CMCD-Request, CMCD-Object, CMCD-Status, CMCD-Session) or the CMCD query parameter. If found, these will be parsed, and the various entries found will be logged using std.log. The next step is to use `varnishncsa` to enrich the transaction logs with information from these CMCD log entries.

- Second, CMSD is an HTTP extension that allows video origins to push metada about content to intermediate server like Varnish. This VCL leverages this extension, more precisely the `nor` attribute of the `CMSD-Static` header to prefetch the objects that will likely be requested next by the user. This feature is implemented in `cmsd-prefetch.vcl`. If the origin doesn't send `cache-control` or `expires` headers, we can rely on CMSD to correctly set expiration dates for each object, depending on whether it's a manifest of a segment, and whether it's a live or VOD stream. This feature is implemented in `cmsd-ttl.vcl`.

## Usage

Copy `cmsd-prefetch.vcl`, `cmsd-ttl.vcl`, `cmcd.vcl`, and `cmcd-cmsd.vcl` to `/etc/varnish/` and include `cmcd-cmsd.vcl` at the top of your VCL like shown below:

```
vcl 4.1;

include "cmcd-cmsd.vcl";

...
```

There is also an example in `default.vcl` in this directory.

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