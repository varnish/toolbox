vcl 4.1;

backend default {
	.host = "httpd";
	.port = "80";
}

include "cmcd-cmsd.vcl";

sub vcl_recv {
	# Your logic here
}

sub vcl_synth {
	# Append to CORS headers here, if needed
}

sub vcl_deliver {
	# Append to CORS headers here, if needed
}
