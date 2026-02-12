# What it is

Two implementations (Python and Shell) that extract the Varnish admin socket configuration given a work directory:
- Management socket addresses and ports (from `-T` argument files)
- Secret file path (from `-S` argument files)

Both implementations produce identical JSON output for non-errors and handle edge cases gracefully.

# How it is built

No need to build anything as it's `shell` and `python`, but you'll need:
- Either:
  - Python 3.6+ (for the Python implementation)
  - A POSIX-compliant shell like `sh` (for the shell implementation) and standard UNIX utilities: `awk`, `tr`, `cat`, `printf`
- `bats` (for running tests)


# How it works

Both scripts accept a directory path (defaults to `/var/lib/varnish/varnishd`) and output JSON:

```bash
# Python
python3 varnish_socket.py [directory]

# Shell
sh varnish_socket.sh [directory]
```

Output format:

```json
{
  "secret": "/path/to/secret",
  "socks": [
    {
      "addr": "127.0.0.1",
      "port": 8080
    }
  ]
}
```

Error cases (missing index, unreadable files) return JSON with an `"error"` field and exit code 1.

# How it is tested

Run tests for both implementations
```bash
test/test_suite.sh
```

Or test a specific implementation
```bash
VARNISH_SOCKET_TOOL=python test/test_suite.sh
VARNISH_SOCKET_TOOL=shell test/test_suite.sh
```