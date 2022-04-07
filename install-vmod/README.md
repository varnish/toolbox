# What it is

A script to download and install vmods. It's mainly aimed at containers since
for other systems, packages are probably more appropriate.

It should be able to build any distribution or source tarball for vmods using autotools, if you find one that doesn't work, please open an [issue](https://github.com/varnish/toolbox/issues/new).

# How it is built

It's a `shell` script so it doesn't need to be built, but you'll probably
want to install it somewhere in your `PATH`

# How it works

Make sure you have the following installed:
- varnish development files
- curl
- pkg-config
- nproc
- make
- gcc/clang
- automake
- libtoolize
- whatever dependencies the vmod needs

From there, you can run

``` bash
install-vmod TARBALL_URL SHA512SUM
```

`TARBALL_URL` is the url to the tarball for the vmod you want to compile.
The tarball is assumed to only have one directory in it.

`SHA512SUM` is an optional `sha512` checksum to validate the tarball against.
