A simple setup demonstrating how you can collect `varnish` logs using various containers.

# Getting started

Start the containers with:

``` shell
docker compose up
```

Put a few files in the `data/` directory and visit [http://localhost/](http://localhost/) to see them ([https://localhost/](https://localhost/) also works, but it's self-signed).

You can check the `ncsa` logs in `logs/`:

``` shell
cat logs/varnishncsa.log
```

Full logs are accessible in `logs/varnishlog.bin` with:

``` shell
docker compose exec varnishlog varnishlog -r /var/log/varnish/varnishlog.bin
```

You can find more information on how to filter and search binary logs in this [tutorial](https://docs.varnish-software.com/tutorials/vsl-query/).
