#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 3 ]; then
	echo "usage: $0 <testsuite.yaml> <database.json> <varnish-license.lic> [parallelism]" >&2
	exit 2
fi

for f in "$1" "$2" "$3"; do
	if [ ! -f "$f" ]; then
		echo "error: file not found: $f" >&2
		exit 2
	fi
done

testsuite=$(realpath "$1")
database=$(realpath "$2")
license=$(realpath "$3")
parallelism=${4:-128}

docker run --rm \
	-v "$testsuite:/tmp/testsuite.yaml:ro" \
	-v "$database:/tmp/devices.json:ro" \
	-v "$license:/etc/varnish/varnish-enterprise.lic:ro" \
	deviceatlas3-tester \
	-db /tmp/devices.json -tests /tmp/testsuite.yaml -parallelism "$parallelism"
