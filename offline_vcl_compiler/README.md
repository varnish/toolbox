# What it is

Varnish notoriously compiles VCL into C, which then needs to be compiled into a
shared object, and this obviously requires a C compiler. Unfortunately, some
organizations are very reluctant having such a compiler on servers, which is
where this tool pair comes into play.

With it, you'll be able to build the shared object on a first machine, and load
it as VCL on a second one, which doesn't need the dreaded C compiler.

# How it is built

Not built, it's just a pair of bash scripts.

# How it works

## Compiling the VCL file into a .so

To build the shared library, we need three things:
- the VCL file we are compiling
- the location of the shared object to produce
- the compiler command to use

For example:

``` bash
./offline_vcl_compiler.sh /etc/varnish/default.vcl foo.so "gcc -march=x86-64 -mtune=generic -O2 -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -fstack-clash-protection -fcf-protection -flto=auto -fno-var-tracking-assignments -Wall -Werror -Wno-error=unused-result -pthread  -fpic -shared -Wl,-x -x c -o /dev/stdout  -"
```

Will generate a file `foo.so` in the current directory. The `gcc` command looks a bit scary, but is really just the default command `varnishd` uses with only a few tweaks. You can check the usage of `[offline_vcl_compiler.sh](offline_vcl_compiler.sh)` to know more.

You can now ship the VCL file and the shared object to the second server.

## Loading the .so as VCL

Because we can't prevent `varnish` from converting the VCL into C (there's a bunch of info derived from that transformation), we need to feed both the shared object AND the original VCL file to the second script.

***note: if you call the script with a VCL file that doesn't match the shared object, THINGS WILL GO WRONG. Do not even try, I'm serious.***

``` bash
./vcl_so_loader.sh default.vcl foo.so
```

Your new VCL should now be loaded, you can check with the following command:

``` bash
varnishadm vcl.list
```

A new line should have appeared, with a VCL sporting a timestamp from a few moments ago.
