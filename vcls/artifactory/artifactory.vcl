vcl 4.1;

import http;
import std;

sub vcl_recv {
	# Avoid caching Docker token requests
	if (req.url ~ "^/(v2/)?token") {
		return (pass);
	}

	# Guard internal headers
	unset req.http.X-Authorization;
	if (req.http.X-Preflight != "check") {
		unset req.http.X-Preflight;
	}

	if (req.http.Authorization && !req.http.X-Preflight && req.method == "GET") {
		# Work around http.req_copy_headers() overwriting duplicate headers
		std.collect(req.http.Accept);

		# Run preflight check
		http.init(16);
		http.req_set_url(16, http.varnish_url(req.url));
		http.req_copy_headers(16);
		http.req_unset_header(16, "Range");
		http.req_set_header(16, "X-Preflight", "check");
		http.req_set_method(16, "HEAD");
		http.req_set_iparam(16, "CURLOPT_SSL_VERIFYHOST", 0);
		http.req_set_iparam(16, "CURLOPT_SSL_VERIFYPEER", 0);
		http.req_send(16);
		http.resp_wait(16);
		if (http.resp_get_status(16) == 200) {
			set req.http.X-Preflight = "authorized";
		} else if (http.resp_get_status(16) > 0) {
			set req.http.X-Preflight = "unknown";
			return (synth(http.resp_get_status(16), http.resp_get_reason(16)));
		}
	}

	# We stow away the Authorization header to avoid return (pass) in builtin.vcl.
	if (req.http.X-Preflight) {
		set req.http.X-Authorization = req.http.Authorization;
		unset req.http.Authorization;
	}
}

sub vcl_hash {
	# Separate preflight checks, authorized objects, and non-authorized objects
	hash_data(req.http.X-Preflight);

	# Separate preflight checks on the Authorization header
	if (req.http.X-Preflight == "check") {
		hash_data(req.http.X-Authorization);
	}

	# Restore Authorization header
	if (req.http.X-Preflight) {
		set req.http.Authorization = req.http.X-Authorization;
		unset req.http.X-Authorization;
	}
}

sub vcl_backend_fetch {
	# Restore request method (this was changed by Varnish core).
	if (bereq.http.X-Preflight == "check") {
		set bereq.method = "HEAD";
	}
}

sub vcl_backend_response {
	if (bereq.http.X-Preflight == "check") {
		# Cache (successful) preflight responses for 1 minute
		set beresp.ttl = 1m;
		set beresp.grace = 0s;
		set beresp.keep = 0s;
		if (beresp.status != 200) {
			set beresp.uncacheable = true;
		}
		return (deliver);
	}
}

sub vcl_synth {
	# The preflight check resulted in a non-200 response
	if (req.http.X-Preflight == "unknown" && http.resp_is_ready(16)) {
		http.resp_copy_headers(16);
		if (http.resp_get_body_len(16) > 0) {
			synthetic(http.resp_get_body(16));
		}
		return (deliver);
	}
}
