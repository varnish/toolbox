vcl 4.1;

backend default { .host = "origin"; }

sub vcl_recv {
       # don't cache if the request path or querystring contains uncacheable
       if (req.url ~ "uncacheable") {
               return (pass);
       # create a synthetic response for heathcheck requests
       } else if (req.url == "/healthcheck") {
               return (synth(200));
       # otherwise, cache
       } else {
               return (hash);
       }
}

sub vcl_backend_response {
	set beresp.ttl = 10s;
}
