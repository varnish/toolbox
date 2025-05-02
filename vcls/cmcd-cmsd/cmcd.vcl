# https://cdn.cta.tech/cta/media/media/resources/standards/pdfs/cta-5004-final.pdf
vcl 4.1;

import str;
import std;
import blob;
import urlplus;
import headerplus;

# Built in subroutines
sub vcl_recv {
	call cmcd;
}

sub vcl_synth {
	call cmcd_cors;
}

sub vcl_deliver {
	call cmcd_cors;
}

# Custom subroutines
sub cmcd {
	if (req.http.CMCD-Request || req.http.CMCD-Object || req.http.CMCD-Status || req.http.CMCD-Session) {
		call cmcd_headers;
	} else if (urlplus.query_get("CMCD") != "") {
		call cmcd_query_parameter;
	}
}

sub cmcd_query_parameter {
	# Ensure that these are not set before we start
	unset req.http.varnish-cmcd-query-raw;
	unset req.http.varnish-cmcd-query;

	# Parse the CMCD query parameter only if no CMCD headers exist
	set req.http.varnish-cmcd-query-raw = urlplus.query_get("CMCD");
	if (req.http.varnish-cmcd-query-raw) {
		std.log("CMCD urlencoded: " + req.http.varnish-cmcd-query-raw);
		set req.http.varnish-cmcd-query = blob.transcode(encoded=req.http.varnish-cmcd-query-raw, decoding = URL);
		std.log("CMCD urldecoded: " + req.http.varnish-cmcd-query);
	}
	if (req.http.varnish-cmcd-query) {
		# XXX: Should check for version here. The logic below assumes CMCD version 1.
		headerplus.init_req();
		if (headerplus.attr_exists("varnish-cmcd-query", "bl")) {
			# Integer
			std.log("cmcd.bl:" + std.integer(headerplus.attr_get("varnish-cmcd-query", "bl"), 0));
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "dl")) {
			# Integer
			std.log("cmcd.dl:" + std.integer(headerplus.attr_get("varnish-cmcd-query", "dl"), 0));
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "mtp")) {
			# Integer
			std.log("cmcd.mtp:" + std.integer(headerplus.attr_get("varnish-cmcd-query", "mtp"), 0));
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "nor")) {
			# String
			# Any value of type String MUST be enclosed by opening and closing double quotes
			std.log("cmcd.nor:" + headerplus.attr_get("varnish-cmcd-query", "nor"));
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "nrr")) {
			# String of the form "<range-start>-<range-end>"
			if (headerplus.attr_get("varnish-cmcd-query", "nrr") ~ "^[0-9]*-[0-9]*$") {
				std.log("cmcd.nrr:" + headerplus.attr_get("varnish-cmcd-query", "nrr"));
			}
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "su")) {
			# Boolean
			std.log("cmcd.su:true");
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "br")) {
			# Integer
			std.log("cmcd.br:" + std.integer(headerplus.attr_get("varnish-cmcd-query", "br"), 0));
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "d")) {
			# Integer
			std.log("cmcd.d:" + std.integer(headerplus.attr_get("varnish-cmcd-query", "d"), 0));
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "ot")) {
			# Token - one of [m,a,v,av,i,c,tt,k,o]
			if (headerplus.attr_get("varnish-cmcd-query", "ot") ~ "^(m|a|v|av|i|c|tt|k|o)$") {
				std.log("cmcd.ot:" + headerplus.attr_get("varnish-cmcd-query", "ot"));
			}
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "tb")) {
			# Integer
			std.log("cmcd.tb:" + std.integer(headerplus.attr_get("varnish-cmcd-query", "tb"), 0));
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "bs")) {
			# Boolean
			std.log("cmcd.bs:true");
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "rtp")) {
			# Integer
			std.log("cmcd.rtp:" + std.integer(headerplus.attr_get("varnish-cmcd-query", "rtp"), 0));
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "cid")) {
			# String
			if (str.len(headerplus.attr_get("varnish-cmcd-query", "cid")) <= 64) {
				std.log("cmcd.cid:" + headerplus.attr_get("varnish-cmcd-query", "cid"));
			}
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "pr")) {
			# Decimal
			std.log("cmcd.pr:" + headerplus.attr_get("varnish-cmcd-query", "pr"));
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "sf")) {
			# Token - one of [d,h,s,o]
			if (headerplus.attr_get("varnish-cmcd-query", "sf") ~ "^(d|h|s|o)$") {
				std.log("cmcd.sf:" + headerplus.attr_get("varnish-cmcd-query", "sf"));
			}
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "sid")) {
			# String
			std.log("cmcd.sid:" + headerplus.attr_get("varnish-cmcd-query", "sid"));
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "st")) {
			# Token - one of [v,l]
			if (headerplus.attr_get("varnish-cmcd-query", "st") ~ "^(v|l)$") {
				std.log("cmcd.st:" + headerplus.attr_get("varnish-cmcd-query", "st"));
			}
		}
		if (headerplus.attr_exists("varnish-cmcd-query", "v")) {
			# Integer
			std.log("cmcd.v:" + std.integer(headerplus.attr_get("varnish-cmcd-query", "v"), 0));
		}

		# Strip CMCD meta data from the request here. This to avoid cache key explosion.
		urlplus.query_delete("CMCD");
		urlplus.write();
	}

	# Clean up before we continue
	unset req.http.varnish-cmcd-query-raw;
	unset req.http.varnish-cmcd-query;
}

# Subroutine that implements support for CMCD version 1
sub cmcd_headers {
	# Parse the CMCD headers if they exist
	if (req.http.CMCD-Request || req.http.CMCD-Object || req.http.CMCD-Status || req.http.CMCD-Session) {
		# XXX: Should check for version here. The logic below assumes CMCD version 1.
		headerplus.init_req();
		if (req.http.CMCD-Request) {
			if (headerplus.attr_exists("CMCD-Request", "bl")) {
				# Integer
				std.log("cmcd.bl:" + std.integer(headerplus.attr_get("CMCD-Request", "bl"), 0));
			}
			if (headerplus.attr_exists("CMCD-Request", "dl")) {
				# Integer
				std.log("cmcd.dl:" + std.integer(headerplus.attr_get("CMCD-Request", "dl"), 0));
			}
			if (headerplus.attr_exists("CMCD-Request", "mtp")) {
				# Integer
				std.log("cmcd.mtp:" + std.integer(headerplus.attr_get("CMCD-Request", "mtp"), 0));
			}
			if (headerplus.attr_exists("CMCD-Request", "nor")) {
				# String
				std.log("cmcd.nor:" + headerplus.attr_get("CMCD-Request", "nor"));
			}
			if (headerplus.attr_exists("CMCD-Request", "nrr")) {
				# String on the form "<range-start>-<range-end>"
				if (headerplus.attr_get("CMCD-Request", "nrr") ~ "^[0-9]*-[0-9]*$") {
					std.log("cmcd.nrr:" + headerplus.attr_get("CMCD-Request", "nrr"));
				}
			}
			if (headerplus.attr_exists("CMCD-Request", "su")) {
				# Boolean
				std.log("cmcd.su:true");
			}
		}
		if (req.http.CMCD-Object) {
			if (headerplus.attr_exists("CMCD-Object", "br")) {
				# Integer
				std.log("cmcd.br:" + std.integer(headerplus.attr_get("CMCD-Object", "br"), 0));
			}
			if (headerplus.attr_exists("CMCD-Object", "d")) {
				# Integer
				std.log("cmcd.d:" + std.integer(headerplus.attr_get("CMCD-Object", "d"), 0));
			}
			if (headerplus.attr_exists("CMCD-Object", "ot")) {
				# Token - one of [m,a,v,av,i,c,tt,k,o]
				if (headerplus.attr_get("CMCD-Object", "ot") ~ "^(m|a|v|av|i|c|tt|k|o)$") {
					std.log("cmcd.ot:" + headerplus.attr_get("CMCD-Object", "ot"));
				}
			}
			if (headerplus.attr_exists("CMCD-Object", "tb")) {
				# Integer
				std.log("cmcd.tb:" + std.integer(headerplus.attr_get("CMCD-Object", "tb"), 0));
			}
		}
		if (req.http.CMCD-Status) {
			if (headerplus.attr_exists("CMCD-Status", "bs")) {
				# Boolean
				std.log("cmcd.bs:true");
			}
			if (headerplus.attr_exists("CMCD-Status", "rtp")) {
				# Integer
				std.log("cmcd.rtp:" + std.integer(headerplus.attr_get("CMCD-Status", "rtp"), 0));
			}
		}
		if (req.http.CMCD-Session) {
			if (headerplus.attr_exists("CMCD-Session", "cid")) {
				# String
				if (str.len(headerplus.attr_get("CMCD-Session", "cid")) <= 64) {
					std.log("cmcd.cid:" + headerplus.attr_get("CMCD-Session", "cid"));
				}
			}
			if (headerplus.attr_exists("CMCD-Session", "pr")) {
				# Decimal
				std.log("cmcd.pr:" + headerplus.attr_get("CMCD-Session", "pr"));
			}
			if (headerplus.attr_exists("CMCD-Session", "sf")) {
				# Token - one of [d,h,s,o]
				if (headerplus.attr_get("CMCD-Session", "sf") ~ "^(d|h|s|o)$") {
					std.log("cmcd.sf:" + headerplus.attr_get("CMCD-Session", "sf"));
				}
			}
			if (headerplus.attr_exists("CMCD-Session", "sid")) {
				# String
				std.log("cmcd.sid:" + headerplus.attr_get("CMCD-Session", "sid"));
			}
			if (headerplus.attr_exists("CMCD-Session", "st")) {
				# Token - one of [v,l]
				if (headerplus.attr_get("CMCD-Session", "st") ~ "^(v|l)$") {
					std.log("cmcd.st:" + headerplus.attr_get("CMCD-Session", "st"));
				}
			}
			if (headerplus.attr_exists("CMCD-Session", "v")) {
				# Integer
				std.log("cmcd.v:" + std.integer(headerplus.attr_get("CMCD-Session", "v"), 0));
			}
		}
	}
}

sub cmcd_cors {
	# Ensure that we allow the client to provide the relevant CMCD headers and methods
	if (resp.http.Access-Control-Allow-Headers) {
		# Only add the individual CMCD headers if they are not already present in the Access-Control-Allow-Headers value.
		headerplus.init_resp();
		if (!headerplus.attr_exists("Access-Control-Allow-Headers", "CMCD-Request")) {
			headerplus.attr_set("Access-Control-Allow-Headers", "CMCD-Request");
		}
		if (!headerplus.attr_exists("Access-Control-Allow-Headers", "CMCD-Object")) {
			headerplus.attr_set("Access-Control-Allow-Headers", "CMCD-Object");
		}
		if (!headerplus.attr_exists("Access-Control-Allow-Headers", "CMCD-Status")) {
			headerplus.attr_set("Access-Control-Allow-Headers", "CMCD-Status");
		}
		if (!headerplus.attr_exists("Access-Control-Allow-Headers", "CMCD-Session")) {
			headerplus.attr_set("Access-Control-Allow-Headers", "CMCD-Session");
		}
	} else {
		set resp.http.Access-Control-Allow-Headers = "CMCD-Request,CMCD-Object,CMCD-Status,CMCD-Session";
	}

	if (resp.http.Access-Control-Allow-Methods) {
		headerplus.init_resp();
		# Only add the individual method if they are not already present in the Access-Control-Allow-Methods value.
		if (!headerplus.attr_exists("Access-Control-Allow-Methods", "GET")) {
			headerplus.attr_set("Access-Control-Allow-Methods", "GET");
		}
	} else {
		set resp.http.Access-Control-Allow-Methods = "GET";
	}
}
