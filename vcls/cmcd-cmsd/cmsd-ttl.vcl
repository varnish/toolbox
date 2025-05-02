vcl 4.1;

import headerplus;

sub vcl_backend_response {
	if (beresp.status == 200 || beresp.status == 206) {
		if (beresp.http.CMSD-Static) {
			call cmsd_ttl;
		}
	} else {
		set beresp.ttl = 1s;
		set beresp.grace = 0s;
	}
}

sub cmsd_ttl {
	# if there's caching information that Varnish can use, back off
	if (beresp.http.cache-control || beresp.http.expires){
		return ;
	}

	unset bereq.http.Object-Type;
	unset bereq.http.Stream-Type;

	headerplus.init(beresp);

	if (headerplus.attr_get("CMSD-Static", "ot")) {
		# Grab the Object-Type value.
		set bereq.http.Object-Type = headerplus.attr_get("CMSD-Static", "ot");
	}
	if (headerplus.attr_get("CMSD-Static", "st")) {
		# Grab the Streaming-Type value.
		set bereq.http.Stream-Type = headerplus.attr_get("CMSD-Static", "st");
	}

	if (bereq.http.Stream-Type == "v") {
		set beresp.ttl = 1y;
	} else if (bereq.http.Object-Type == "a" ||
		   bereq.http.Object-Type == "v" ||
		   bereq.http.Object-Type == "av") {
		set beresp.ttl = 5m;
	} else {
		set beresp.ttl = 1s;
		set beresp.grace = 0s;
	}

	unset bereq.http.Object-Type;
	unset bereq.http.Stream-Type;
}
