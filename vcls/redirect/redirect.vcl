import std;

sub vcl_recv {
	# make sure no one uses that header but us to avoid injections
	unset req.http.location;

	# this assumes that HTTPS requests are received on port 443, and
	# redirects all requests arriving on another port.
	if (std.port(server.ip) != 443) {
		set req.http.location = "https://" + req.http.host + req.url;
		return (synth (301));
	}
}

sub vcl_synth {
	# recognize redirect and hijack processing
	if (resp.status == 301 ||
	    resp.status == 302 ||
	    resp.status == 303 ||
	    resp.status == 307) {
		# we need a location
		if (!req.http.location) {
			std.log("location not specified");
			set resp.status = 503;
			return (deliver);
		} else {
			set resp.http.location = req.http.location;
			return (deliver);
		}
	}
}
