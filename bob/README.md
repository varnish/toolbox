# What it is

A tool to help setup bob-enabled projects. It builds container with the
necessary tools to build said project.

# How it is built

To use `bob` properly it is recommended to copy the `bob` bash script into a directory  
listed in your PATH env or to create symlink with the same logic.
System wide or ~ based is a matter of personal choice :)

# How it works

Get in your project directory, and prefix any build command with `bob`:

```
bob make
bob go build
...
```

It relies on a `bob/Dockerfile` at the root of the directory, which will
allow it to create the containers.

You can force the rebuild of the image using `bob build`

Set the `BOB_DIST` env variable to target a particular distribution, and to
us a specific `bob/Dockerfile.$BOB_DIST`

# How it is not complete

Some ideas:

- use a hash to differentiate project with the same name
- implement a `name` command to return the name of the image create
- allow arguments when running a container
- allow running from non-home directory
