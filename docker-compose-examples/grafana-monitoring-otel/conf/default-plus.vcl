vcl 4.1;

import vtc;
import std;
import ykey;

include "otel.vcl";

backend esi { .host = "origin-esi"; }
backend files { .host = "origin-files"; }

sub vcl_recv {
	set req.http.x-route = regsub(req.url, "\?.*", "");
	otel.route(req.http.x-route);
	if (req.url ~ "esi") {
		set req.backend_hint = esi;
	} else {
		set req.backend_hint = files;
	}

	if (req.url == "/?cacheable-10") {
		vtc.sleep(7.5s);
		std.log("BUG: we don't support fetching /?cacheable-10");
		return(synth(503));
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

	otel.route(bereq.http.x-route);
	set beresp.do_esi = true;
	if (bereq.url == "/esi_sub1" && bereq.retries == 1) {
		std.log("BUG: deliberately slowing down the second fetch of /esi_sub1");
#		vtc.sleep(700ms);
	}
	if (bereq.url == "/esi_sub1" && bereq.retries < 3) {
		return(retry);
	}
	set beresp.ttl = 50s;
}
