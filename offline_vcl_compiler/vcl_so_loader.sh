#!/bin/sh

set -e

usage() {
	cat << EOF
Usage: $0 VCL_PATH SO_PATH [VARNISHADM_PARAMS]
EOF
}

if [ $# -eq 0 ]; then
	usage
	exit 1
fi

VCL_PATH="$(realpath "$1")"
SO_PATH="$(realpath "$2")"
AUTH="$3"

cp $SO_PATH /var/lib/varnish/varnishd/my.so
varnishadm $AUTH param.set cc_command "\"exec cp /var/lib/varnish/varnishd/my.so %o\""
varnishreload $VCL_PATH 
