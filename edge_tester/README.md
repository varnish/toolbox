# What this is

A simple script to test HTTP servers with multiple URLs.

# Build

```
go build
```

# Run

`edges.yml` is a list of hosts:

```
- srv-1.example.com
- srv-2.example.com
```

`urls.yml` is a list of urls:

```
  # full URL
- url: https://example.com/test
  # Accepted status code
  returns:
    - 404
  # headers to add to the request
  heders:
    debug: true
    user-agent: edge-tester

```

If there's any issue, you'll get a report with a way to reproduce with a command line tool.

```
# ./edge_tester edges.yml urls.yml
- name: example.com
  ipv4: 23.192.228.84
  ipv6: 2600:1406:3a00:21::173e:2e66
  errors:
    - reproducer: curl -o /dev/null -qsv "https://example.com/test" --connect-to "example.com:443:23.192.228.84:443"
      error: status code 404 not in [200]
    - reproducer: curl -o /dev/null -qsv "https://example.com/test" --connect-to "example.com:443:[2600:1406:3a00:21::173e:2e66]:443"
      error: status code 404 not in [200]
```
