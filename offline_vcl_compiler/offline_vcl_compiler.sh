#!/bin/sh

set -e

usage() {
	cat << EOF
Usage: $0 VCL_PATH OUTPUT_PATH CC_COMMAND
	Compiles the file as VCL_PATH into a shared library to be loaded into
	varnish in a second step.
	
	CC_COMMAND should compile data comming from stdin and output it to
	stdout, for example:
		gcc -shared -x c -o /dev/stdout -

	you should be able to grab the output of
		varnishadm param.show cc_command
	and replace:
		- %o with "-"
		- %s with "-"
		- %w with the output of "varnishadm param.show cc_warnings"

	Don't forget to quote CC_COMMAND!
EOF
}

if [ $# -ne 3 ]; then
	usage
	exit 1
fi

VCL="$(realpath "$1")"
OUT="$2"
CC_COMMAND="$3"

varnishd -C -f "$VCL" 2>&1 | sed '/^Could not rmdir /d' | $CC_COMMAND > "$OUT"
#                            ^ remove this sed once varnish is fixed
#
#varnishd -C -f "$()"
#exec gcc -march=x86-64 -mtune=generic -O2 -pipe -fno-plt -fexceptions         -Wp,-D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security         -fstack-clash-protection -fcf-protection -flto=auto -fno-var-tracking-assignments %w -pthread  -fpic -shared -Wl,-x -o %o %s
#
#varnishadm param.set 
#varnishadm param.reset cc_command
