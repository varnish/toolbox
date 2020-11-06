# What it is

A tool to help new users to set up the Varnish Enterprise repositories.
Start the script, answer a few questions and you are good to go.

Note that you will need your repository token for it to work. Please contact
sales@varnish-software.com to get yours.

# How it is built

Not built, it's just a bash script.

# How it works

Run it, answer the questions and let the script install the required files and
packages. There's a bare OS detection to retrieve `curl`, but mostly, we just
ask the user.

It can also be used in a non-interactive manner, using environment variables.
For example:

``` bash
TOKEN=XXXXXX INSTALL="varnish-plus varnish-plus-ha" easy_install/script.sh
```

Use `easy_install/script.sh help` to see the full list.
