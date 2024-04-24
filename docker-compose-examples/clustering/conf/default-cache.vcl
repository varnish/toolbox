vcl 4.1;

import activedns;

include "cluster.vcl";

backend default { .host = "origin:80"; }

sub vcl_init {
  new cluster_group = activedns.dns_group("varnish:6081");
  cluster.subscribe(cluster_group.get_tag());

  cluster_opts.set("token", "my_very_secret_secret");
}

sub vcl_backend_fetch {
  set bereq.backend = default;
}

sub vcl_backend_response {
	if (beresp.http.cluster-path) {
		set beresp.http.cluster-path = server.identity + " -> " + beresp.http.cluster-path;
	} else {
		set beresp.http.cluster-path = server.identity + " -> origin";
	}
}
