#!/bin/sh
#
# Test runner for Varnish socket extractors
# Runs BATS tests for one or both implementations

set -e

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
BATS_FILE="$TEST_DIR/test_suite.bats"

# If VARNISH_SOCKET_TOOL is not set, test both implementations
if [ -z "$VARNISH_SOCKET_TOOL" ]; then
    echo "Running tests for Python implementation..."
    VARNISH_SOCKET_TOOL=python bats "$BATS_FILE"
    
    echo ""
    echo "Running tests for Shell implementation..."
    VARNISH_SOCKET_TOOL=shell bats "$BATS_FILE"
else
    # Run tests for the specified implementation
    bats "$BATS_FILE"
fi
