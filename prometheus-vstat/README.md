# What it is

`prometheus-vstat` is a simple program exposing `varnish` metrics in the
[prometheus](https://prometheus.io/) format.

It's fairly opinionated and will try its best to format the counters in a
sensible way, notably for `MSE` counters.

# How it is built

Make sure you have both `go` and `make` installed, then just run `make`:

``` bash
make
```

# How it works

It can be used from the command-line directly:

```
# grab metrics live from varnishstat
prometheus-vstat
# convert a JSON file
prometheus-vstat -input file.json
# read from `stdin`
some_command | prometheus-vstat -input -
```

Alternatively, it can be called from Varnish Plus using `pvstat.vcl`. Check the
comments of this file for more information.

# How it's not complete

It's currently only support Varnish (Plus) <= 6.4 due to a `varnishstat` format
change.
