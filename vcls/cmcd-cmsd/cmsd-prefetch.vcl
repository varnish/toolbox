vcl 4.1;

import http;
import headerplus;
import std;
import str;
import urlplus;

backend default none;

sub vcl_recv {
	# This will give our base url name, following above: https://example.com (will also work for ip and port address)
	urlplus.parse(req.url);
	if (urlplus.url_as_string() ~ "/$") {
		set req.http.X-Prefetch-Dirname-URL = http.varnish_url(urlplus.url_as_string());
	} else if (urlplus.get_dirname() ~ "/$") {
		set req.http.X-Prefetch-Dirname-URL = http.varnish_url(urlplus.get_dirname());
	} else {
		set req.http.X-Prefetch-Dirname-URL = http.varnish_url(urlplus.get_dirname()) + "/";
	}
	set req.http.X-Prefetch-No-Path-URL = regsub(http.varnish_url(""), "/$", "");
	set req.http.X-Prefetch-Host = req.http.host;
}

sub cmsd_prefetch {
	# no header, no work, no problem
	if (!beresp.http.CMSD-Static) {
		return;
	}

	headerplus.init(beresp);
	set bereq.http.X-Prefetch-URLs = headerplus.attr_get("CMSD-Static", "nor");

# nor #1
	# do the nor elements look like a relative path? If not, bail
	if (!str.split(bereq.http.X-Prefetch-URLs, 1, "|") ||
	    str.split(bereq.http.X-Prefetch-URLs, 1, "|") == "" ||
	    str.split(bereq.http.X-Prefetch-URLs, 1, "|") ~ "^https?://") {
		return;
	}
	http.init(0);
	http.req_set_max_loops(0, 3);
	if (str.split(bereq.http.X-Prefetch-URLs, 1, "|") ~ "^/") {
		http.req_set_url(0, bereq.http.X-Prefetch-No-Path-URL + str.split(bereq.http.X-Prefetch-URLs, 1, "|"));
	} else {
		http.req_set_url(0, bereq.http.X-Prefetch-Dirname-URL + str.split(bereq.http.X-Prefetch-URLs, 1, "|"));
	}
	http.req_set_header(0, "host", bereq.http.X-Prefetch-Host);
	http.req_send_and_finish(0);

# nor #2
	if (!str.split(bereq.http.X-Prefetch-URLs, 2, "|") ||
	    str.split(bereq.http.X-Prefetch-URLs, 2, "|") == "" ||
	    str.split(bereq.http.X-Prefetch-URLs, 2, "|") ~ "^https?://") {
		return;
	}
	http.init(0);
	http.req_set_max_loops(0, 3);
	if (str.split(bereq.http.X-Prefetch-URLs, 2, "|") ~ "^/") {
		http.req_set_url(0, bereq.http.X-Prefetch-No-Path-URL + str.split(bereq.http.X-Prefetch-URLs, 2, "|"));
	} else {
		http.req_set_url(0, bereq.http.X-Prefetch-Dirname-URL + str.split(bereq.http.X-Prefetch-URLs, 2, "|"));
	}
	http.req_set_header(0, "host", bereq.http.X-Prefetch-Host);
	http.req_send_and_finish(0);

# nor #3
	if (!str.split(bereq.http.X-Prefetch-URLs, 3, "|") ||
	    str.split(bereq.http.X-Prefetch-URLs, 3, "|") == "" ||
	    str.split(bereq.http.X-Prefetch-URLs, 3, "|") ~ "^https?://") {
		return;
	}
	http.init(0);
	http.req_set_max_loops(0, 3);
	if (str.split(bereq.http.X-Prefetch-URLs, 3, "|") ~ "^/") {
		http.req_set_url(0, bereq.http.X-Prefetch-No-Path-URL + str.split(bereq.http.X-Prefetch-URLs, 3, "|"));
	} else {
		http.req_set_url(0, bereq.http.X-Prefetch-Dirname-URL + str.split(bereq.http.X-Prefetch-URLs, 3, "|"));
	}
	http.req_set_header(0, "host", bereq.http.X-Prefetch-Host);
	http.req_send_and_finish(0);
}

sub vcl_backend_response {
	call cmsd_prefetch;
}
