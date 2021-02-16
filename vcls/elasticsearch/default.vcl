vcl 4.1;

import file;
import http;
import std;
import synthbackend;
import xbody;

sub vcl_init {
	new fs = file.init("/etc/varnish/");
}

backend default none;

sub vcl_recv {
	if(req.method == "OPTIONS") {
		return(synth(200));
	}
	if(req.method != "POST" || req.url != "/docs/search") {
		return(synth(403));
	}

	std.cache_req_body(100KB);
	set req.http.x-body = xbody.get_req_body();

	return(hash);
}

sub vcl_hash {
	hash_data(req.http.x-body);
	hash_data(fs.lastmodified("search.json"));
}

sub vcl_backend_fetch {
	set bereq.http.x-parsed-body = regsub(fs.read("search.json"),"<<SEARCH>>", bereq.http.x-body);

	http.init(0);
	http.req_set_url(0, "http://elasticsearch:9200/docs/doc/_search?pretty");
	http.req_set_header(0, "Content-Type", "application/json");
	http.req_set_sparam(0, "POSTFIELDS", bereq.http.x-parsed-body);
	http.req_send(0);
	http.resp_wait(0);

	set bereq.backend = synthbackend.from_blob(http.resp_get_body_blob(0));
}

sub vcl_backend_response {
	set beresp.status = http.resp_get_status(0);
	if(beresp.status == 200) {
		set beresp.ttl = 1h;
	} else {
		set beresp.uncacheable = true;
	}    
}

sub vcl_deliver {
	set resp.http.Access-Control-Allow-Origin = "*";
	set resp.http.Access-Control-Allow-Methods = "POST, OPTIONS";
}
