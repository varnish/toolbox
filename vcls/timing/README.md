# Timing VCL

Contrary to most VCLs here, `timing.vcl` isn't really meant to be included in
your own VCL, mainly because the code is so small it makes no sense to have its 
own file (just copy-paste as you need). Rather, it's meant
as an example on how you can use the `now` variable as well as `vmod-std` to
compute durations between two VCL subroutines.

This is a pure-VCL solution, and therefore comes with a couple of pitfalls you
should be aware of.

First, because of how HTTP works, we can only convey metadata through headers,
which are sent *before* the response body, and so this method cannot be used to
tell the client the total processing time spent on a request. Notably, you
won't get the time spent sending the response body. What you do get though is
the time it took to find/create the object to send back to the client.

If you want precise, comprehensive measurements, you should look at
[VSL timestamps](https://varnish-cache.org/docs/trunk/reference/vsl.html#timestamps)
and [how to extract/filter them](https://docs.varnish-software.com/tutorials/vsl-query/).

Second, you won't get timing information for `pipe`d requests, since Varnish
will not have access to the response, so it can't touch the headers. It's
pretty minor, but it has surprised people in the past.

If you really want to try it before adopting it, you can include `timing.vcl`
at the beginning of your VCL, and you should see the headers
`recv-to-deliver-duration` and `recv-to-synth-duration` appear in your
responses.

``` vcl
vcl 4.1;

include "timing.vcl"

// rest of our VCL below
```

To run the test case:

``` bash
varnishtest timing01.vtc
```
