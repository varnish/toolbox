vcl 4.1;

import vtc;

include "/etc/varnish/otel.vcl";

backend esi { .host = "origin-esi"; }
backend files { .host = "origin-files"; }

sub vcl_recv {
	if (req.url ~ "esi") {
		set req.backend_hint = esi;
	} else {
		set req.backend_hint = files;
	}

	# don't cache if the request path or querystring contains uncacheable
	if (req.url ~ "uncacheable" || req.url ~ "esi") {
		return (pass);
	# create a synthetic response for heathcheck requests
	} else if (req.url == "/healthcheck") {
		return (synth(200));
	# otherwise, cache
	} else {
		return (hash);
	}
}

sub vcl_backend_response {
	set beresp.do_esi = true;
	if (bereq.url == "/esi_sub1" && bereq.retries == 1) {
		std.log("taking a break, I need it");
		vtc.sleep(700ms);
	}
	if (bereq.url == "/esi_sub1" && bereq.retries < 3) {
		return(retry);
	}
	set beresp.ttl = 10s;
}

include "verbose_builtin.vcl";

sub vcl_backend_response {
	set beresp.ttl = 1y;
}
