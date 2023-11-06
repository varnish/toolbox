# Verbose "built-in" VCL

The [built-in VCL](https://varnish-cache.org/docs/trunk/users-guide/vcl-built-in-code.html)
is a piece of VCL that systematically gets appended to your own configuration.
It has two purposes:
- ensure that the C code it's compiled into is valid, i.e. has a return value
- provide some sensible default behavior

The problem with the second point is that sometimes, while sensible and safe,
the built-in decisions can be a bit confusing unless you know the built-in
code well. And even when you do, parsing the logs and understanding what
happened can be a bit frustrating.

So, this piece of VCL aims to alleviate that issue by providing a more explicit
VCL. In practice, this is just the 7.4 built-in VCL with a handful of
`std.log()` thrown in, resulting in hopefully helpful messages like:

```
...
-   ReqMethod      POST
-   ReqURL         /
-   ReqProtocol    HTTP/1.1
-   ReqHeader      Host: localhost:6081
-   ReqHeader      User-Agent: curl/8.4.0
-   ReqHeader      Accept: */*
-   ReqHeader      X-Forwarded-For: ::1
-   ReqHeader      Via: 1.1 flamp (Varnish/7.4)
-   VCL_call       RECV
-   VCL_Log        built-in rule: returning pass (method is neither GET nor HEAD) <---- this line
-   VCL_return     pass
...
```

# Installation and use

Simply copy the [verbose_builtin.vcl](./verbose_builtin.vcl) in your
`/etc/varnish/` directory and include it **at the bottom** of your top VCL:

```
vcl 4.1;

import cookie;
import vtc;
...

include "custom.vcl";
include "more_custom.vcl";
...

sub vcl_init {
   ...
}

...

include "verbose_builtin.vcl";
# nothing should exist past that line
```
