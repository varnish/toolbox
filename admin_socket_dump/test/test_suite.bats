#!/usr/bin/env bats

# Test suite for Varnish configuration extractors
# Tests Python or shell implementation based on VARNISH_SOCKET_TOOL variable
#
# Usage:
#   VARNISH_SOCKET_TOOL=python bats test/test_suite.bats
#   VARNISH_SOCKET_TOOL=shell bats test/test_suite.bats
#   Or use test/test_suite.sh to test both implementations

setup() {
    ASSETS_DIR="$BATS_TEST_DIRNAME/assets"
    
    case "$VARNISH_SOCKET_TOOL" in
        python)
            SCRIPT="python3 $BATS_TEST_DIRNAME/../varnish_socket.py"
            ;;
        shell)
            SCRIPT="sh $BATS_TEST_DIRNAME/../varnish_socket.sh"
            ;;
        *)
            echo "VARNISH_SOCKET_TOOL must be set to 'python' or 'shell'" >&2
            exit 1
            ;;
    esac
}

@test "normal case: both secret and socks present" {
    run $SCRIPT "$ASSETS_DIR/normal"
    [ "$status" -eq 0 ]
    
    expected='{
  "secret": "/tmp/test.secret",
  "socks": [
    {
      "addr": "127.0.0.1",
      "port": 8080
    },
    {
      "addr": "::1",
      "port": 8081
    }
  ]
}'
    [ "$output" = "$expected" ]
}

@test "no secret: only socks present" {
    run $SCRIPT "$ASSETS_DIR/no_secret"
    [ "$status" -eq 0 ]
    
    expected='{
  "secret": null,
  "socks": [
    {
      "addr": "192.168.1.1",
      "port": 9000
    }
  ]
}'
    [ "$output" = "$expected" ]
}

@test "no socks: only secret present" {
    run $SCRIPT "$ASSETS_DIR/no_socks"
    [ "$status" -eq 0 ]
    
    expected='{
  "secret": "/etc/varnish/secret",
  "socks": []
}'
    [ "$output" = "$expected" ]
}

@test "empty socks: secret present but socks file is empty" {
    run $SCRIPT "$ASSETS_DIR/empty_socks"
    [ "$status" -eq 0 ]
    
    expected='{
  "secret": "/var/secret",
  "socks": []
}'
    [ "$output" = "$expected" ]
}

@test "neither: no -T or -S arguments in index" {
    run $SCRIPT "$ASSETS_DIR/neither"
    [ "$status" -eq 0 ]
    
    expected='{
  "secret": null,
  "socks": []
}'
    [ "$output" = "$expected" ]
}

@test "invalid directory returns error" {
    run $SCRIPT "$ASSETS_DIR/invalid_dir"
    [ "$status" -eq 1 ]
    
    # Both implementations return error JSON, but with different messages
    case "$output" in
        *'"error"'*) ;;
        *) return 1 ;;
    esac
}

@test "missing -T file: gracefully returns empty socks" {
    run $SCRIPT "$ASSETS_DIR/missing_t_file"
    [ "$status" -eq 1 ]
    
    # File is referenced in index but doesn't exist - should error
    case "$output" in
        *'"error"'*) ;;
        *) return 1 ;;
    esac
}

@test "missing -S file: gracefully returns null secret" {
    run $SCRIPT "$ASSETS_DIR/missing_s_file"
    [ "$status" -eq 1 ]
    
    # File is referenced in index but doesn't exist - should error
    case "$output" in
        *'"error"'*) ;;
        *) return 1 ;;
    esac
}

@test "malformed socks data: skips invalid lines" {
    run $SCRIPT "$ASSETS_DIR/malformed_socks"
    [ "$status" -eq 0 ]
    
    # Should skip malformed lines and only return valid socket entries
    expected='{
  "secret": "/var/secret",
  "socks": [
    {
      "addr": "192.168.1.1",
      "port": 9000
    }
  ]
}'
    [ "$output" = "$expected" ]
}
