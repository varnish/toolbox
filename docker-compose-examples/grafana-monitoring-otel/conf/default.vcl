vcl 4.1;

import vtc;
import std;
import ykey;

include "otel.vcl";

backend esi { .host = "origin-esi"; }
backend files { .host = "origin-files"; }

sub vcl_recv {
	otel.route(req.url);
	if (req.url ~ "esi") {
		set req.backend_hint = esi;
	} else {
		set req.backend_hint = files;
	}

	# don't cache if the request path or querystring contains uncacheable
	if (req.url ~ "uncacheable" || req.url ~ "esi") {
		return (hash);
	# create a synthetic response for heathcheck requests
	} else if (req.url == "/healthcheck") {
		return (synth(200));
	# otherwise, cache
	} else {
		return (hash);
	}
}

sub vcl_backend_response {
	# just creating some ykey action to fill the graphs
	ykey.add_key(bereq.url);
	ykey.purge_keys(bereq.url);

	otel.route(bereq.url);
	set beresp.do_esi = true;
	if (bereq.url == "/esi_sub1" && bereq.retries == 1) {
		std.log("taking a break, I need it");
		vtc.sleep(700ms);
	}
	if (bereq.url == "/esi_sub1" && bereq.retries < 3) {
		return(retry);
	}
	set beresp.ttl = 50s;
}
