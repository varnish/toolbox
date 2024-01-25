sub vcl_recv {
	unset req.http.x-cache;
}

sub vcl_hit {
	set req.http.x-cache = "hit";
	if (obj.ttl <= 0s && obj.grace > 0s) {
		set req.http.x-cache = "hit graced";
	}
}

sub vcl_miss {
	set req.http.x-cache = "miss";
}

sub vcl_pass {
	set req.http.x-cache = "pass";
}

sub vcl_pipe {
	set req.http.x-cache = "pipe uncacheable";
}

sub vcl_synth {
	set req.http.x-cache = "synth synth";
	# comment the following line to omit the x-cache header in the response
	set resp.http.x-cache = req.http.x-cache;
}

sub vcl_deliver {
	if (obj.uncacheable) {
		set req.http.x-cache = req.http.x-cache + " uncacheable" ;
	} else {
		set req.http.x-cache = req.http.x-cache + " cached" ;
	}

	# comment the following line to omit the x-cache header in the response
	set resp.http.x-cache = req.http.x-cache;
}
