vcl 4.1;

import activedns;
import udo;

backend default none;

sub vcl_init {
  activedns.set_default_ttl(5s);

  new caches_group = activedns.dns_group("cache:6081");
  caches_group.set_ttl(5s);
  caches_group.set_ttl_rule(force);

  new caches = udo.director();
  caches.set_type(random);
  caches.subscribe(caches_group.get_tag());
}

sub vcl_recv {
  set req.backend_hint = caches.backend();
  return (pass);
}
