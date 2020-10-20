# What it is

A script to convert VTC logs into JUnit reports. It's used notably in
circleci to prettify the test suite results.

# How it is built

It's a `python` script so it doesn't need to be built, but you'll probably
install it somewhere in you `PATH` 

# How it works

``` bash
junitizer.py INPUT_DIRECTORY XML_OUPUT
```

`INPUT_DIRECTORY` will be the directory containing the `vtc`, `log` and `trs`
file to path (the directory will be scanned recursively).

`XML_OUPUT` is the name of the `xml` file to be produced.
