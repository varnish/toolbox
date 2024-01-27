vcl 4.1;
import http;

backend default {
    .host = "127.0.0.1";
    .port = "8080";
}

sub vcl_recv {
	unset req.http.X-Authorization;
	unset req.http.X-Client-Authorized;
	unset req.http.X-Method;

	# Authorize GET request by looping a HEAD request through Varnish
	if (req.http.Authorization && req.method == "GET") {
		http.init(0);
		http.req_set_url(0, http.varnish_url(req.url));
		http.req_copy_headers(0);
		http.req_set_method(0, "HEAD");
		http.req_send(0);
		http.resp_wait(0);
		if (http.resp_get_status(0) != 200) {
			return (synth(403));
		}

		set req.http.X-Client-Authorized = "true";
	}

	# Stow away the HEAD request method
	if (req.method == "HEAD") {
		set req.http.X-Method = "HEAD";
	}

	# We stow away the Authorization header to avoid return (pass) in builtin.vcl.
	# This is safe because GET requests are authorized with a HEAD request loop,
	# and HEAD requests make the X-Authorization header a part of the cache key.
	if (req.http.Authorization) {
		set req.http.X-Authorization = req.http.Authorization;
		unset req.http.Authorization;
	}
}

sub vcl_hash {
	if (req.http.X-Client-Authorized != "true") {
		hash_data(req.http.X-Authorization);
	}
	if (req.http.X-Method) {
		hash_data(req.http.X-Method);
	}
}

sub vcl_backend_fetch {
	# Restore the Authorization header.
	if (bereq.http.X-Authorization) {
		set bereq.http.Authorization = bereq.http.X-Authorization;
		unset bereq.http.X-Authorization;
	}

	# Restore the original request method (this is changed by varnish core).
	if (bereq.http.X-Method == "HEAD") {
		set bereq.method = "HEAD";
		unset bereq.http.X-Method;
	}
}
