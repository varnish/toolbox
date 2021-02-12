# Redirect VCL

`redirect.vcl` is a minimalist snippet that you can include at the top of your
own vcl to simplify HTTP redirects. It does two things:
- redirects non-HTTPS traffic to HTTPS
- provides a simple framework to handle redirects

Simply including the file (placed in `/etc/varnish`) is enough to benefit from
the first point. For the second one, the VCL writer just needs to set
`req.http.location` trigger a synthetic response with a redirect code (typically
301 or 302):

``` vcl
vcl 4.0;

include "redirect.vcl"

backend default { .host = "1.2.3.4:8080"; }

sub vcl_recv {
	# make sure the host header is the right one
	if (req.http.host != "my.domain.com") {
		set req.http.location = "https://my.domain.com" + req.url;
		return (synth(301));
	}
}
```

To run the test case:

``` bash
varnishtest redirect.vtc
```
