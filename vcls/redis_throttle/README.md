# Throttling using `redis` VCL

Varnish being a reverse-proxy, it is often tasked with rate-limiting traffic, for many reasons:
- the backend can't take too many requests in a short window of time
- an individual user, identified by a cookie or by an IP, isn't allowed to query the system to often
- a particular endpoint is a bit brittle and traffic must be limited

The very natural answers to those needs is [vmod_vsthrottle](https://github.com/varnish/varnish-modules/blob/master/src/vmod_vsthrottle.vcc)
that does just that: you give it a key, a period and a number of threshold and it'll tell you
is a certain request should be denied. However, the quotas are kept in memory, and aren't shared,
which makes the logic hard to scale when you have more than a few Varnish nodes.

Instead, we can usea `redis` database and [vmod_redis](https://github.com/carlosabalde/libvmod-redis)
to keep track of the various quotas to enforce.

To use this VCL:
- install `vmod_redis`, for example using [easy_install](https://github.com/varnish/toolbox/tree/master/easy_install).
- open `redis_throttle.vcl` and edit it in all the places commented with `# EDIT` 
- copy `redis_throttle.vcl` in `/etc/varnish` on your server
- in your own VCL (probably `/etc/varnish/default.vcl`), add `include "redis_throttle.vcl"` right after (the `vcl 4.x` line)
