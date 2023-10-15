# What it is

A dummy example demonstrating how one can use [go templates](https://pkg.go.dev/text/template) to generate VCL code.

As you VCL grow, you may experience difficulties getting rid of redundancies, having to repeat certain patterns over and over. It's generally not important from a performance angle since VCL gets compiled into native code and is blazing fast. However, code repetition is a maintenance burden and can be error-prone, so a common solution is to decorrelate logic and data, putting the former in a template, and the other in a declarative format.

The solution presented here is:
- not for production use. **I mean it**
- a starting point for you if it's your first time using templates and you find the whole thing daunting
- just an illustration of generic concepts
- not a recommendation to use `go` over `javascript` or `rust` or `helm` or any other language

With that being said, feel free to ask any questions or precisions you feel are necessary if something seem unclear, the example is pared down for clarity, but it should answer most newcomers' questions.

# How it's build

You will need a somewhat recent version of [go](https://go.dev/). Anything provided by your usual Linux/\*BSD distribution should be fine.

Build the `gotemplate-example` binary with:

``` bash
go build
```

# How it works

You should have a few file in the current directory:
- `go.mod` and `go.sum`: don't worry about those, they are `go` module dependency files
- `main.go`: the source file of the binary aforementioned
- **`gotemplate-example`**: the binary tool you just built
- **`vcl.tmpl`**: the VCL template, i.e. the logic 
- **`conf.yaml`**: the data that will fill your template to create the final, usable VCL

Of these, only the last three are important, and you can use them like this:

``` bash
# print the final VCL:
./gotemplate-example conf.yaml vcl.tmpl
# or save the output in a file named default.vcl:
./gotemplate-example conf.yaml vcl.tmpl > default.vcl
```

And that is it, `gotemplate-example` parses the YAML file, reads the template, fuses them together and prints the output. The YAML file can contain any kind of data (notably, it is **not** typechecked) and the template can use whatever is in the YAML. From there, experiment, tweak the configuration to add more backends, change the value of the `env` field in `config.yaml` and see what changes it brings to the final VCL.
