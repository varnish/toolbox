vcl 4.1;

backend default { .host = "origin:80"; }

sub vcl_backend_response {
	# don't cache bad responses
	if (beresp.status != 200) {
		set beresp.ttl = 5s;
		return (deliver);
	}

	# by default, grace is 10s, which can mess up playback by
	# overcaching the manifest, let's zero it
	set beresp.grace = 0s;

	# if we're delivering live, we can't cache for too long
	if (bereq.url ~ "^/live/") {
		if (bereq.url ~ "\.m3u8") {
			# notably, manifests are only good for a short period of time
			set beresp.ttl = 1s;
		} else {
			# chunks can be cached for much longer
			set beresp.ttl = 5m;
		}
	} else {
		# otherwise it's vod, we can possibly cache forever
		set beresp.ttl = 1y;
	}
}

sub vcl_deliver {
	# we want to be playable from any website
	# https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS
	set resp.http.Access-Control-Allow-Origin = "*";
}
