# Cache invalidation VCL

There are a lot of way to invalidate content from a Varnish cache, and this
directory aims to provide a reference implementation for the most common ones,
in an easily integrable package.

There are two different files: `invalidate_os.vcl` targets the open-source
version of Varnish Cache, and `invalidate_plus.vcl` target the Enterprise
version, Varnish Cache Plus.

While `invalidate_os.vcl` is usable by both versions, `invalidate_plus.vcl`
requires the Enterprise edition and features an extra invalidation method and a
slightly different approach to option handling.

# `invalidate_os.vcl`

## Getting started

Here's how to use the vcl:

``` vcl
vcl 4.1;

# first, include the file at the top of your VCL
# (usually /etc/varnish/default.vcl)
include "invalidate_os.vcl";

# in vcl_recv, we then need to set a few headers before calling the invalidate
# function
sub vcl_recv {
	# by default, all methods are allowed, but we can disable some
	set req.http.invalidate-purge-allow = "false";
	# or set options for others
	set req.http.invalidate-ban-ignore-host = "true";

	# and most importantly, we need to check if the request is authorized to
	# invalidate the cache
	if (req.http.authorization == "bearer VerySecretTokenToPurge") {
		set req.http.invalidate-user-authorized = "true";
	}

	# we can then call invalidate which will use the values we just set
	call invalidate;
}
```

## Securing access

By default, no request is trusted to invalidate the cache, as it's a fairly
critical operation, so it's up to the VCL writer to define who it is safe to
trust.

Here are a few examples.

### Trust everyone

Never use this in production, but it's an easy to solution if you need to focus
on the actual invalidation rather than on the access control. Any request can
invalidate.

``` vcl
sub vcl_recv {
	set req.http.invalidate-user-authorized = "true";
	call invalidate;
}
```

### bearer token

Mandate a bearer token to allow access, the example below is dead simple with
a static string, but you can use something more advanced like a [JWT]https://docs.varnish-software.com/varnish-cache-plus/vmods/jwt/#examples)
string.

``` vcl
sub vcl_recv {
	if (req.http.authorization == "bearer VerySecretTokenToPurge") {
		set req.http.invalidate-user-authorized = "true";
	}
	call invalidate;
}
```

### cookie and ACL

This last example combines both a cookie check with an IP allowlist so that only
internal clients with the proper secret can invalidate the cache.

``` vcl
import cookie;

acl internal {
	"192.168.0.1"/24;
	"192.168.1.1"/24;
}

sub vcl_recv {
	cookie.parse(req.http.cookie);
	if (cookie.get("invalidator") == "VerySecretTokenToPurge" &&
	    client.ip ~ internal) {
		set req.http.invalidate-user-authorized = "true";
	}
	call invalidate;
}
```

## Return codes

Upon successful invalidation, Varnish will reply with a 200 response and a
"Successful <method>" (with the number of objects banned for tag-based
invalidation).

Otherwise, a 405 ("Unauthorized method") will be returned, with a specific
reason to help debugging.

## Tests

All tests are suffixed with either `_os` for the open-source VCL or with `_plus`
for the Enterprise code.

This directory has a `.bob` directory, meaning you can leverage [bob](https://github.com/varnish/toolbox/tree/master/bob)
(available in this same directory):

``` bash
# for the open-source tests:
../../bob/bob varnishtest invalidate_os*.vtc
# for the Enterprise tests (you'll need a subscription):
../../bob/bob varnishtest invalidate_plus*.vtc
```

Alternatively, you can use the provided `Makefile`:

``` bash
make
make tests_os
make tests_plus
```

## Invalidation methods

Different methods have different inputs and act in different way, read on to
pick the one that is right for you.
An important point is that all the ways presented below, while they may have
different performance profiles at scale will both be totally fine on small and
medium setups and always synchronous: once the invalidation successfully
returns, no invalidated content will be served by Varnish.

### Purge

Purging is the simplest way to remove content from Varnish and allow you to
target a specific URL. It is implemented here with the `PURGE` method,
for example:

``` bash
$ curl -X PURGE http://192.168.0.34/path/to/object/to/purge.html -H "host: example.com"
Successful purge
```

Note the use of `-H` to force the `host` header. It's important because a purge
relies on hashing a request to find the object to remove, so the `PURGE` request
must match the `GET` request that inserted it (at least the `host` and `path`).

API:
- method: must be `PURGE`
- URL: must match the purged object
- path: must match the purged object
- in `vcl_recv`, `req.http.invalidate-purge-allow` must be `"true"` (the default)

### Ban

Banning is broader than a purge and allows to remove objects based on specific
properties. It's a very powerful and generic way to perform cache invalidation,
and in this implementation, it's used to invalidate entire subtrees of content.

For example:

``` bash
$ curl -X BAN http://192.168.0.34/path/to/directory/to/purge/ -H "host: example.com"
Successful ban
```

will invalidate any object with a URL matching
`example.com/path/to/directory/to/purge/*`.

It's also possible to ignore the `host`, if you set the
`invalidate-ban-ignore-host`header in your VCL, the previous `curl` command will
invalidate all the `*/path/to/directory/to/purge/`.

``` vcl
sub vcl_recv {
	set req.http.invalidate-ban-ignore-host = "true";
	...
	call invalidate;
}
```

API:
- method: must be `BAN`
- URL: must match the purged object
- path: must match the purged object
- in `vcl_recv`, `req.http.invalidate-ban-allow` must be `"true"` (the default)
- in `vcl_recv`, `req.http.invalidate-ban-ignore-host` (defaults to `"false"`) decides if the `host` header is ignored

### Zero

Sometimes it's necessary to just wipe the whole cache, without discrimination.
This is done using the `ZERO` method, and in this case, the `host` and `path`
don't matter at all:

``` bash
$ curl -X ZERO http://192.168.0.34/
Successful zero
```

API:
- method: must be `ZERO`

# `invalidate_plus.vcl`

The Enterprise version of this VCL works similarly to its open-source
counterpart except for two points:
- the extra tag-based invalidation is available
- a [key-value vmod](https://docs.varnish-software.com/varnish-cache-plus/vmods/kvstore/)
  is used to avoid writing options into headers. This shortens the implementation
  and streamline the [logs](https://docs.varnish-software.com/tutorials/vsl-query/)

The original vcl snippet translate to this with the Enterprise version:

``` vcl
vcl 4.1;

include "invalidate_plus.vcl";

sub vcl_recv {
	invalidate_opts.set("req.http.invalidate-purge-allow", "true");
	invalidate_opts.set("ban-ignore-host", "true");

	if (req.http.authorization == "bearer VerySecretTokenToPurge") {
		invalidate_opts.set("user-authorized", "true");
	}

	# we can then call invalidate which will use the values we just set
	call invalidate;
}
```

However, the HTTP APIs and the `curl` examples show above will work exactly the
same way, the change is only at the VCL level.

## Invalidation methods

### Purge

API:
- method: must be `PURGE`
- URL: must match the purged object
- path: must match the purged object
- in `invalidate_opts`, `purge-allow` must be `"true"` (the default)

### Ban

API:
- method: must be `BAN`
- URL: must match the purged object
- path: must match the purged object
- in `invalidate_opts`, `ban-allow` must be `"true"` (the default)
- in `invalidate_opts`, `ban-ignore-host` (defaults to `"false"`) decides if the `host` header is ignored

### Zero

API:
- method: must be `ZERO`

### Tag-based invalidation

It is possible to apply tags to content to classify it. For video platforms, we
can apply tags based on bitrate, channel, format, etc., for e-commerce websites,
each resources can be flagged based on it's type and price range for example.

Based on these tags, Varnish Plus can invalidate entire classes of objects
thanks to [ykey](https://docs.varnish-software.com/varnish-cache-plus/vmods/ykey/).
`invalidate_plus.vcl` simplifies the implementation and only requires the VCL
writer to specify which tag to apply to objects when they enter the cache:

``` vcl
sub vcl_recv {
	...
	call invalidate;
}

sub vcl_backend_response {
	# trust the backend and apply all the tags in the "product-tags" header
	ykey.add_header(beresp.http.product-tags);
	# also use the backend name as a tag
	ykey.add_key(beresp.backend);
}
```

The method used here is `RMTAG` and disregards both the `host` and `path` to
focus only on the `rmtag-list` containing the list of tags to flush.

``` bash
$ curl -X ZERO http://192.168.0.34/ -H "rmtag-list: foo, bar, qux"
Successful rmtag: 532876 objects removed
```

API:
- method: must be `RMTAG`
- `rmtag-list` header: contains a comma-separated list of tags to invalidate
