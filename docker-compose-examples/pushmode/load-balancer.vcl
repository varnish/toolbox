vcl 4.1;

import activedns;
import goto;
import kvstore;
import std;
import udo;

backend default none;

sub vcl_init {
    new origins_group = activedns.dns_group("push-origin:6081");
    origins_group.set_ttl_rule(force);
    origins_group.set_ttl(1s);

    new origins = udo.director();
    origins.subscribe(origins_group.get_tag());
}


sub vcl_recv {
    set req.backend_hint = origins.backend();
    return (pass);
}

sub vcl_backend_fetch {
    if (bereq.http.force-origin) {
    	set bereq.backend = goto.dns_backend(bereq.http.force-origin);
    }
}

sub vcl_backend_response {
    set beresp.http.origin = beresp.backend;
}
