#!/bin/sh

set -e

export BOB_DIR=bob_testdir

cd $(dirname "$0")/..
# try to build all images
for dist in alpine centos debian ubuntu; do
	echo "> testing with $dist"
	BOB_DIST=$dist ./bob
done
