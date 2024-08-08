# What it is

Two different Varnish implementations of [uap-core](https://github.com/ua-parser/uap-core/)
allowing Varnish to classify a user-agent string and extracts some information from them.
It's not as advanced as `deviceAtlas`, but it relies on an open-database.

The first implementation targets [Varnish Enterprise](https://www.varnish-software.com/products/varnish-enterprise/) and uses [vmod-rewrite](https://docs.varnish-software.com/varnish-enterprise/vmods/rewrite/)
to match the user-agent with the database entries.
The second one is a pure-VCL implementation suitable for [Varnish Cache](https://varnish-cache.org/). It's slower than the Varnish Enterprise option, but it requires no vmod.

# How it is built

You'll need:
- `go` >= 1.16
- `make`
- `curl`
- either Varnish Cache or Varnish Enterprise

``` bash
# build 
make

# run tests on Enterprise
make check-enterprise

# or on Cache
make check-oss
```

# How it works

Running `make` will generate both `uap-enterprise.vcl` `uap-enterprise.vtc`. Include either of them and call `uap_detect` (they both implement it) from a client subroutine such as `vcl_recv`.

As a result, `uap_detect` will populate these request headers (`req.http.*`) matching the results found in `regexes.yaml`:
- `ua-family`
- `ua-major`
- `ua-minor`
- `ua-patch`
- `os-family`
- `os-major`
- `os-minor`
- `os-patch`
- `os-patch_minor`
- `device-family`
- `device-brand`
- `device-model`

Example VCL:

``` vcl
vcl 4.1;

import std;

include "./uap-oss.vcl";

backend default none;

sub vcl_recv {
    call uap_detect;
    std.log("device family is: " + req.http.device-family);
    return (synth(200));
}
```
