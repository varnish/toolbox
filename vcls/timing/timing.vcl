# this VCL comes wit ha few caveats, read the README first!

# we are going to need vmod-std for some conversions
import std;

sub vcl_recv {
    # as soon as we enter VCL, i.e. at the top of vcl_recv, we store the
    # current time (`now`). Note that we use `std.real()` here, if we don't,
    # `now` will be converted into an HTTP date string, like
    # "Wed, 21 Oct 2015 07:28:00 GMT", which as you can see, loses sub-second
    # information. So instead, we encode it first as a real, which only then
    # get stringified
    set req.http.initial-timestamp = std.real(time = now);
}

# on the way out, we simply retrieve the original time, with the inverse
# transformation (i.e. string->real->date) and we substract it from the
# current `now`.
sub vcl_deliver {
    set resp.http.recv-to-deliver-duration = now - std.time(real = std.real(req.http.initial-timestamp));
}

sub vcl_synth {
    set resp.http.recv-to-synth-duration = now - std.time(real = std.real(req.http.initial-timestamp));
}
