# Redirect VCL

Full tutorial on the [Varnish Software docs website](https://docs.varnish-software.com/tutorials/hit-miss-logging/)

`hit-miss.vcl` will tag Varnish responses with a `x-cache` header to inform the
user of how their request was process (hit, miss, pass, etc.). It's useful for
the end users as well as for admins wishing to filter logs more easily.

To use it, simply include it at the top of your `vcl`:

``` vcl
vcl 4.0;

include "hit-miss.vcl"

backend default { .host = "1.2.3.4:8080"; }

...
```

If you prefer to not announce that kind of information to the end user, or
maybe do it conditionally only for trusted users, you can edit
`hit-miss.vcl` to avoid setting `resp.http.x-cache` (just follow the
comments).


To run the test case:

``` bash
varnishtest hit-miss.vtc
```
