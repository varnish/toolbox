# Cache invalidation

There are a lot of way to invalidate content from a Varnish cache, and this
directory aims to provide a reference implementation for the most common ones,
in an easily integrable package.

You'll find two folders: `invalidate_os/` targets the open-source
version of Varnish Cache, and `invalidate_plus/` targets the Enterprise
version, Varnish Cache Plus.

Both implement the same HTTP interface, but invalidate_plus/invalidate.vcl`
offers a few extra options and can only be used by Varnish Cache Plus`.

# Installation

## Varnish Cache

Copy `invalidate_os/invalidate.vcl` as `/etc/varnish/invalidate.vcl` on your
Varnish server, and add at the top of `/etc/varnish/default.vcl`:

``` vcl
vcl 4.1;

include "invalidate.vcl";

sub vcl_recv {
	set req.http.invalidate-bearer-token == "VerySecretToken";
	call invalidate;
}
```

## Varnish Cache Plus

Copy `invalidatei_plus/invalidate.vcl` as `/etc/varnish/invalidate.vcl` on your
Varnish server, and add at the top of `/etc/varnish/default.vcl`:

``` vcl
vcl 4.1;

include "invalidate.vcl";

sub vcl_recv {
	invalidate_opts.set("bearer-token", "VerySecretToken");
	call invalidate;
}
```

# HTTP API

Different methods have different inputs and act in different way, read on to
pick the one that is right for you.
An important point is that all the ways presented below, while they may have
different performance profiles at scale will both be totally fine on small and
medium setups and always synchronous: once the invalidation successfully
returns, no invalidated content will be served by Varnish.

## Return codes

Upon successful invalidation, Varnish will reply with a 200 response and a
"Successful <method>" (with the number of objects banned for tag-based
invalidation).

Otherwise, a 405 ("Unauthorized method") will be returned, with a specific
reason to help debugging.


## PURGE: invalidate a single object

Purging is the simplest way to remove content from Varnish and allow you to
target a specific URL. It is implemented here with the `PURGE` method,
for example:

``` bash
$ curl -X PURGE http://192.168.0.34/path/to/object/to/purge.html -H "host: example.com" -H "authorization: bearer VerySecretToken"
Successful purge request
```

Note the use of `-H` to force the `host` header. It's important because a purge
relies on hashing a request to find the object to remove, so the `PURGE` request
must match the `GET` request that inserted it (at least the `host` and `path`).

## BANDIR: invalidate a subtree

Banning is broader than a purge and allows to remove objects based on specific
properties. It's a very powerful and generic way to perform cache invalidation,
and in this implementation, it's used to invalidate entire subtrees of content.

For example:

``` bash
$ curl -X BANDIR http://192.168.0.34/path/to/directory/to/purge/ -H "host: example.com" -H "authorization: bearer VerySecretToken"
Successful ban request
```

will invalidate any object with a URL matching
`example.com/path/to/directory/to/purge/*`.

## BANALL: invalidate everything

Sometimes it's necessary to just wipe the whole cache, without discrimination.
This is done using the `PURGEALL` method, and in this case, the `host` and `path`
don't matter at all:

``` bash
$ curl -X PURGEALL http://192.168.0.34/ -H "authorization: bearer VerySecretToken"
Successful banall request
```

## PURGETAG: invalidate tagged content (plus only)

It is possible to apply tags to content to classify it. For video platforms, we
can apply tags based on bitrate, channel, format, etc., for e-commerce websites,
each resources can be flagged based on it's type and price range for example.

Based on these tags, Varnish Plus can invalidate entire classes of objects
thanks to [ykey](https://docs.varnish-software.com/varnish-cache-plus/vmods/ykey/).
`invalidate.vcl` simplifies the implementation and only requires the VCL
writer to specify which tag to apply to objects when they enter the cache:

``` vcl
sub vcl_backend_response {
	# trust the backend and apply all the tags in the "product-tags" header
	ykey.add_header(beresp.http.product-tags);
	# and also use the backend name as a tag
	ykey.add_key(beresp.backend);
}
```

The method used here is `PURGETAG` and disregards both the `host` and `path` to
focus only on the `purgetag-list` containing the list of tags to flush.

``` bash
$ curl -X PURGETAG http://192.168.0.34/ -H "purgetag-list: foo, bar, qux" -H "authorization: bearer VerySecretToken"
Successful purgetag request: 532876 objects removed
```

# VCL API

To avoid having to modifying the included VCL file directly, you can set various
options directly from in the including file, usually from `vcl_recv`, before
calling invalidate.

The two VCL versions are slightly different approaches, but the names are kept
aligned and examples are provided for both versions.

For the open-source version, request headers prefixed with `invalidate-` are
used while in the Plus version, [kvstore](https://docs.varnish-software.com/varnish-cache-plus/vmods/kvstore/)
is used to keep the request (and logs) free from distraction.

## `purge-allow`, `ban-allow`, `banall-allow`, `purgetag-allow`

Each of the different invalidation method can be forbidden individually by
setting the corresponding option to `"false"` (they are all `"true"` by
default).

``` vcl
# Open-source
sub vcl_recv {
	...
	set req.http.invalidate-purge-allow = "false";
	set req.http.invalidate-bandir-allow = "false";
	set req.http.invalidate-banall-allow = "false";
	call invalidate;
}
```


``` vcl
# Plus
sub vcl_recv {
	...
	invalidate_opts.set("purge-allow", "false");
	invalidate_opts.set("bandir-allow", "false");
	invalidate_opts.set("banall-allow", "false");
	invalidate_opts.set("purgetag-allow", "false");
	call invalidate;
}
```

## `bandir-ignore-host`

When invalidating a subtree, by default, the deletion is focused on the `host`
specified in the invalidation request. By setting `bandir-ignore-host` to 
"true"`, one can invalidate all the matching subtrees across all the domains.


``` vcl
# Open-source
sub vcl_recv {
	...
	set req.http.invalidate-bandir-ignore-host = "true";
	call invalidate;
}
```

``` vcl
# Plus
sub vcl_recv {
	...
	invalidate_opts.set("bandir-ignore-host", "true");
	call invalidate;
}
```

## `bearer-token`

By setting the `bearer-token` to a non-empty string, the VCL writer can set
the secret invalidation requests must set to be trusted.

*Note: if combined with `ip-acl`, requests must fulfill both requirements, and if
neither is set, all invalidation requests will be denied.*

``` vcl
# Open-source
sub vcl_recv {
	...
	set req.http.invalidate-bearer-token == "VerySecretToken";
	call invalidate;
}
```

``` vcl
# Plus
sub vcl_recv {
	...
	invalidate_opts.set("bearer-token", "VerySecretToken");
	call invalidate;
}
```

## `ip-acl` (Plus only)

`ip-acl` can be empty to disable checks or a comma-separated IP list as required
by [aclplus](https://docs.varnish-software.com/varnish-cache-plus/vmods/aclplus/).
In that case the client's IP is checked against this list to be trusted.

*Note: if combined with `bearer-token`, requests must fulfill both
requirements, and if neither is set, all invalidation requests will be denied.*

``` vcl
# Open-source
sub vcl_recv {
	...
	set req.http.invalidate-ip-vcl == "VerySecretToken";
	call invalidate;
}
```

``` vcl
# Plus
sub vcl_recv {
	...
	invalidate_opts.set("ip-vcl", "VerySecretToken");
	call invalidate;
}
```

## `authorized-user`

If custom access control schemes are required, it's possible to use the
`authorized-user` variable directly. It starts as `"false"` but if it is set
to `"true"` before calling `invalidate`, the request will be trusted, regardless
of `ip-acl` and `bearer-token`.

``` vcl
# Open-source
sub vcl_recv {
	...
	# only URLs starting with "/static/" can be purge, if the user-agent
	# header contains "Mozilla"
	if (req.url ~ "^/static/" && req.http.user-agent ~ "Mozilla") {
		set req.http.invalidate-authorized-header == "true";
	}
	call invalidate;
}
```

``` vcl
# Plus
sub vcl_recv {
	...
	# only URLs starting with "/static/" can be purge, if the user-agent
	# header contains "Mozilla"
	if (req.url ~ "^/static/" && req.http.user-agent ~ "Mozilla") {
		invalidate_opts.set("authorized-header", "true");
	}
	call invalidate;
}
```


# Tests

Test are run using `varnishtest` from within `invalidate` or `invalidate_plus/`:

``` bash
varnishtest -j 4 *.vtc
```

You can also leverage [bob](https://github.com/varnish/toolbox/tree/master/bob)
(available in this same repository) to run the test in a container:

``` bash
../../../bob/bob varnishtest -j 4 *.vtc
