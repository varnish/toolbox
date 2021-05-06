// automatically set a few headers that we'll use as configuration
// this file shouldn't be modified, instead, the option should be set in
// vcl_recv from the file including this one
sub vcl_recv {
	// PURGE, BAN and PURGEALL are allowed by default
	set req.http.invalidate-purge-allow = "true";
	set req.http.invalidate-ban-allow = "true";
	set req.http.invalidate-purgeall-allow = "true";

	// BAN should take the host header into acount
	set req.http.invalidate-ban-ignore-host = "false";

	// the default is to not trust a request, until told otherwise
	set req.http.invalidate-user-authorized = "false";

	// this header will be use to report back to the user, so we clear it
	unset req.http.invalidate-message;
}

sub invalidate {
	// for each method, check if the configuration allows it, and invalidate
	// according to it, setting req.http.invalidate-message
	if (req.method == "PURGE") {
		if (req.http.invalidate-user-authorized != "true") {
			set req.http.invalidate-message = "Unauthorized request";
			return (synth(405));
		}
		if (req.http.invalidate-purge-allow != "true") {
			set req.http.invalidate-message = "PURGE is disabled on this host";
			return (synth(405));
		}
		set req.http.invalidate-message = "Successful purge request";
		return (purge);
	} else if (req.method == "BAN") {
		if (req.http.invalidate-user-authorized != "true") {
			set req.http.invalidate-message = "Unauthorized request";
			return (synth(405));
		}
		if (req.http.invalidate-ban-allow != "true") {
			set req.http.invalidate-message = "BAN is disabled on this host";
			return (synth(405));
		}
		if (req.http.invalidate-ban-ignore-host == "true") {
			ban("obj.http.invalidate-url ~ ^" + req.url);
		} else {
			ban("obj.http.invalidate-url ~ ^" + req.url + " && obj.http.invalidate-host == " + req.http.host);
		}
		set req.http.invalidate-message = "Successful ban request";
		return (synth(200));
	} else if (req.method == "PURGEALL") {
		if (req.http.invalidate-user-authorized != "true") {
			set req.http.invalidate-message = "Unauthorized request";
			return (synth(405));
		}
		if (req.http.invalidate-purgeall-allow != "true") {
			set req.http.invalidate-message = "PURGEALL is disabled on this host";
			return (synth(405));
		}
		ban("obj.status != 0");
		set req.http.invalidate-message = "Successful purgeall request";
		return (synth(200));
	}
}

// we remove the headers to avoid leaking them to the backend
sub vcl_backend_fetch {
	unset bereq.http.invalidate-purge-allow;
	unset bereq.http.invalidate-ban-allow;
	unset bereq.http.invalidate-purgeall-allow;
	unset bereq.http.invalidate-ban-ignore-host;
	unset bereq.http.invalidate-user-authorized;
	unset bereq.http.invalidate-message;
}

// add headers to beresp before it enters the cache, and make it a function
// to use fromboth v_b_r and v_b_e
sub invalidate_flag {
	set beresp.http.invalidate-url = bereq.url;
	set beresp.http.invalidate-host = bereq.http.host;
}

sub vcl_backend_response {
	call invalidate_flag;
}

sub vcl_backend_error {
	call invalidate_flag;
}

// remove headers before sending the reponse sso the users don't see them
sub vcl_deliver {
	unset resp.http.invalidate-url;
	unset resp.http.invalidate-host;
}

// check if req.http.invalidate-message and use it if so, short-circuiting the
// usual function
sub vcl_synth {
	if (req.http.invalidate-message) {
		synthetic (req.http.invalidate-message);
		return (deliver);
	}
}
