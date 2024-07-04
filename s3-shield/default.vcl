vcl 4.1;

import std;
import kvstore;
import headerplus;
import s3;

include "aws/auto_init.vcl";
include "aws/sign.vcl";
include "cluster.vcl";

backend default none;

sub vcl_init {
	if (!aws_config.get("region")) {
		if (aws_config.get("s3_bucket_address") ~ ".*\.s3\.([^.]+)\.amazonaws\.com.*") {
			aws_config.set("region", regsub(aws_config.get("s3_bucket_address"), ".*\.s3\.([^.]+)\.amazonaws\.com.*", "\1"));
		} else if (aws_config.get("algorithm") == "GOOG4-RSA-SHA256") {
			aws_config.set("region", "no-region");
		} else {
			return (fail("region wasn't set and couldn't be extracted from s3_bucket_address"));
		}
	}
	aws_config.set("s3_bucket_host", regsub(aws_config.get("s3_bucket_address"), ":[0-9]+$", ""));

	new bucket = s3.director(regsub(aws_config.get("s3_bucket_address"), "^([a-zA-Z0-9.-]+)\\.s3\\..*$", "\1"), regsub(aws_config.get("s3_bucket_address"), ".*\.s3\.([^.]+)\.amazonaws\.com.*", "\1"), aws_config.get("s3_bucket_address"));

	if ( std.duration(aws_config.get("s3_ttl"), 123456789123456789s) == 123456789123456789s ) {
		return (fail("Invalid TTL duration, must be a number followed by ms, s, m, h, d, w, or y"));
	} else if ( std.duration(aws_config.get("s3_ttl"), 0s) <= 0s ) {
		aws_config.set("s3_ttl", "0s");
	}
}

sub vcl_recv {
	# Remove the query string from the URL, remove cookies, remove authorization headers
	set req.url = regsub(req.url, "\?.*$", "");
	unset req.http.Cookie;
	unset req.http.Authorization;
	set req.http.Host = aws_config.get("s3_bucket_host");

	# Request method options
	if (req.method != "GET" && req.method != "HEAD") {
		return (synth(405, "Method Not Allowed"));
	}

	# If TTL is 0s, we return(pass)
	if (aws_config.get("s3_ttl") == "0s") {
		return(pass);
	}
}

sub vcl_backend_fetch {
	set bereq.backend = bucket.backend();
	std.log("AWS Host: " + aws_config.get("s3_bucket_address"));
	std.log("AWS Region: " + aws_config.get("region"));
	#if credentials has key get and use the value
	if (aws_credentials.get("aws_access_key_id")) {
		std.log("Credentials: Yes");
		call aws_sign_bereq;
	} else{
		# if there is no credentials use case
		std.log("Credentials: No");
	}
}

sub vcl_backend_response {
	if (beresp.status == 200) {
		set beresp.ttl = std.duration(aws_config.get("s3_ttl"), 600s);
		set beresp.grace = 1s;
		set beresp.keep = 1y;
	} else {
		set beresp.ttl = 5s;
		set beresp.grace = 0s;
	}
}

sub vcl_backend_error {
	# Retry backend requests when a transport error occurs.
	return(retry);
}
