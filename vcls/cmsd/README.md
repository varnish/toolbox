# CMSD integration for Varnish

## Features

[Common Media Server Data](https://shop.cta.tech/products/web-application-video-ecosystem-common-media-server-data-cta-5006) is an HTTP extension that allows video origins to push metada about content to intermediate server like Varnish.

### Video prefetching

This VCL leverages this extension, more precisely the `nor` attribute of the `CMSD-Static` header to prefetch the objects that will likely be requested next by the user.

This feature is implemented in `cmsd-prefetch.vcl`.

### TTL setting

If the origin doesn't send `cache-control` or `expires` headers, we can rely on CMSD to correctly set expiration dates for each object, depending on whether it's a manifest of a segment, and whether it's a live or VOD stream.

This feature is implemented in `cmsd-ttl.vcl`.

## Installation

Copy `cmsd*.vcl` to `/etc/varnish/` and include it at the top of your VCL:

```
vcl 4.1;

include "cmsd.vcl";

...
```

**Note:** this VCL uses Entreprise vmods ([http](https://docs.varnish-software.com/varnish-enterprise/vmods/http/), [headerplus](https://docs.varnish-software.com/varnish-enterprise/vmods/headerplus/) and [urlplus](https://docs.varnish-software.com/varnish-enterprise/vmods/urlplus/)), therefore you will need Varnish Enterprise to use it.
