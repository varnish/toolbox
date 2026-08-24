vcl 4.1;

import deviceatlas3;
import std;

backend default none;

sub vcl_init {
	if (deviceatlas3.loadfile(std.getenv("DEVICEATLAS_DB_PATH")) != 0) {
		return (fail);
	}
}

sub vcl_recv {
	return (synth(200));
}

sub vcl_synth {
	if (req.http.deviceatlas-full-lookup == "true") {
		set resp.http.deviceatlas-results = deviceatlas3.lookup_all(req.http.deviceatlas-property);
	} else {
		set resp.http.deviceatlas-results = deviceatlas3.lookup(req.http.User-Agent, req.http.deviceatlas-property);
	}
	return (deliver);
}
