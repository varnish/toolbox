#!/bin/sh
#
# Extract Varnish configuration from _.index file.
# Reads the _.index file to find:
# - Management interface IP/ports (from -T argument)
# - Secret file path (from -S argument)
#

set -eu

# Function to check if file exists and exit with error if not
check_file() {
    if [ ! -f "$1" ]; then
        printf '{"error": "%s file not found: %s"}\n' "$2" "$1" >&2
        exit 1
    fi
}

# Get directory from command line argument or use default
WORK_DIR="${1:-/var/lib/varnish/varnishd}"

# Construct path to _.index file
INDEX_DIR="$WORK_DIR/_.vsm_mgt"
INDEX_PATH="$INDEX_DIR/_.index"

# Check if index file exists
check_file "$INDEX_PATH" "Index"

# Parse the index file to find -T and -S argument files
ARG_T_FILE=$(awk '/Arg -T$/ {print $2}' "$INDEX_PATH")
ARG_S_FILE=$(awk '/Arg -S$/ {print $2}' "$INDEX_PATH")

# Build full paths
ARG_T_FULL_PATH="$INDEX_DIR/$ARG_T_FILE"
ARG_S_FULL_PATH="$INDEX_DIR/$ARG_S_FILE"

# Read secret file path (if present in index)
SECRET="null"
if [ -n "$ARG_S_FILE" ]; then
    # If file is referenced but doesn't exist, that's an error
    check_file "$ARG_S_FULL_PATH" "Secret argument"
    SECRET=$(cat "$ARG_S_FULL_PATH" | tr -d '\0')
    SECRET=$(printf '%s' "$SECRET")
    SECRET="\"$SECRET\""
fi

# Read IP/ports and build JSON array (if present in index)
SOCKS_JSON=""
if [ -n "$ARG_T_FILE" ]; then
    # If file is referenced but doesn't exist, that's an error
    check_file "$ARG_T_FULL_PATH" "Management address argument"
    COMMA=""
    
    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue
        
        # Split address and port
        ADDR="${line% *}"
        PORT="${line##* }"
        
        # Skip if we couldn't split properly
        [ -z "$ADDR" ] || [ -z "$PORT" ] && continue
        
        # Add socket entry
        SOCKS_JSON="${SOCKS_JSON}${COMMA}
    {
      \"addr\": \"$ADDR\",
      \"port\": $PORT
    }"
        COMMA=","
    done <<EOF
$(awk 'NF==2' "$ARG_T_FULL_PATH")
EOF
fi

# Output JSON
if [ -z "$SOCKS_JSON" ]; then
    # Empty socks array
    cat <<EOF
{
  "secret": $SECRET,
  "socks": []
}
EOF
else
    # Non-empty socks array
    cat <<EOF
{
  "secret": $SECRET,
  "socks": [$SOCKS_JSON
  ]
}
EOF
fi
