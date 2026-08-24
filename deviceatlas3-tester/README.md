# deviceatlas3-tester

Test harness for `vmod-deviceatlas3` (https://docs.varnish-software.com/varnish-enterprise/vmods/deviceatlas3/).
Starts a real `varnishd` with the vmod loaded, feeds it requests defined in a
YAML test suite, and checks the resulting `deviceatlas-results` header
against the expected value declared for each case.

## Test suite format

A YAML file containing a flat list of test cases:

```yaml
- name: iphone-safari
  request:
    headers:
      User-Agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X)..."
  full_lookup: false
  expected:
    isMobilePhone: "1"
    vendor: "Apple"

- name: client-hints-full-lookup
  request:
    headers:
      Sec-CH-UA-Mobile: "?1"
      Sec-CH-UA-Platform: "\"Android\""
  full_lookup: true
  expected:
    isMobilePhone: "1"
```

- `request.headers`: headers to send on the test request (e.g. `User-Agent`,
  `Sec-CH-UA*`).
- `expected`: map of property name -> the exact string that property lookup
  must return. One request is sent per entry.
- `full_lookup`: `false` calls `deviceatlas3.lookup()` (User-Agent only),
  `true` calls `deviceatlas3.lookup_all()` (all request headers, including
  Client Hints).

See `testdata/example-suite.yaml` for a fuller example.

## Building and running

```bash
docker build -t deviceatlas3-tester .

./run.sh testsuite.yaml devices.json varnish-license.lic [parallelism]
```

You can also run the docker container manually:

```bash
docker run --rm \
  -v /tmp/testsuite.yaml:/tmp/testsuite.yaml:ro \
  -v /tmp/devices.json:/tmp/devices.json:ro \
  -v /tmp/varnish-license.lic:/etc/varnish/varnish-enterprise.lic:ro \
  deviceatlas3-tester \
  -db /tmp/devices.json -tests /tmp/testsuite.yaml -parallelism 8
```

Flags:

- `-db` (required): path to the DeviceAtlas database file, as visible inside
  the container.
- `-tests` (required): path to the YAML test suite file, as visible inside
  the container.
- `-parallelism` (default `128`): number of test cases to run concurrently.

There's no license flag: mount your license file read-only at
`/etc/varnish/varnish-enterprise.lic`, `varnishd`'s default license path.

Exit code is non-zero if any test case fails.

## How it works

- `default.vcl` is a static VCL file baked into the image at
  `/etc/varnish/default.vcl`. It reads the DeviceAtlas database path from the
  `DEVICEATLAS_DB_PATH` environment variable via `std.getenv()` in
  `vcl_init`. The tester sets that variable (from `-db`) on the `varnishd`
  child process it starts via
  [varnish-go](https://pkg.go.dev/github.com/varnish/varnish-go)'s `vtest`
  package.
- `vcl_recv` always returns `synth(200)`. `vcl_synth` calls
  `deviceatlas3.lookup()` or `deviceatlas3.lookup_all()` depending on the
  `deviceatlas-full-lookup` request header, and sets the result on the
  `deviceatlas-results` response header.
- Each entry in a case's `expected` map is a separate property lookup, so it
  becomes its own request: same `request.headers` and `full_lookup`, with
  `deviceatlas-property` set to that map key. The response's
  `deviceatlas-results` is compared against the map value.
