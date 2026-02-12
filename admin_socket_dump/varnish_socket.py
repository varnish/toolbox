#!/usr/bin/env python3
"""
Extract Varnish configuration from _.index file.
Reads the _.index file to find:
- Management interface IP/ports (from -T argument)
- Secret file path (from -S argument)
"""

import sys
import json
import os
from pathlib import Path

def parse_index_file(index_path):
    """Parse _.index file to find -T and -S arguments."""
    arg_t_file = None
    arg_s_file = None
    
    with open(index_path, 'r') as f:
        for line in f:
            line = line.strip()
            parts = line.split()
            if len(parts) >= 2:
                if line.endswith('Arg -T'):
                    # Second word is the path to the file with IP/ports
                    arg_t_file = parts[1]
                elif line.endswith('Arg -S'):
                    # Second word is the path to the secret file
                    arg_s_file = parts[1]
    
    return arg_t_file, arg_s_file

def read_ip_ports(file_path):
    """Read IP/ports from the -T argument file."""
    sockets = []
    with open(file_path, 'rb') as f:
        content = f.read()
        # Strip null bytes and decode
        content = content.rstrip(b'\x00').decode('utf-8')
        sockets = [
            {"addr": parts[0], "port": int(parts[1])}
            for line in content.split('\n')
            if line.strip()
            for parts in [line.strip().rsplit(maxsplit=1)]
            if len(parts) == 2
        ]
    
    return sockets

def read_secret_path(file_path):
    """Read the secret file path from the -S argument file."""
    with open(file_path, 'rb') as f:
        content = f.read()
        # Strip null bytes and decode
        content = content.rstrip(b'\x00').decode('utf-8').strip()
        return content

def main():
    # Get directory from command line argument or use default
    if len(sys.argv) > 1:
        work_dir = sys.argv[1]
    else:
        work_dir = '/var/lib/varnish/varnishd'
    
    # Construct path to _.index file
    index_dir = os.path.join(work_dir, '_.vsm_mgt')
    index_path = os.path.join(index_dir, '_.index')
    
    # Read IP/ports from -T file and secret file path from -S file
    try:
        # Parse the index file
        arg_t_file, arg_s_file = parse_index_file(index_path)
        
        # Build full paths (files are in the same directory as _.index)
        
        # Read IP/ports from -T file (if present in index)
        socks = []
        if arg_t_file:
            arg_t_full_path = os.path.join(index_dir, arg_t_file)
            # If file is referenced but doesn't exist, that's an error
            socks = read_ip_ports(arg_t_full_path)
        
        # Read secret file path from -S file (if present in index)
        secret = None
        if arg_s_file:
            arg_s_full_path = os.path.join(index_dir, arg_s_file)
            # If file is referenced but doesn't exist, that's an error
            secret = read_secret_path(arg_s_full_path)
    except (ValueError, FileNotFoundError, PermissionError, Exception) as e:
        print(json.dumps({
            "error": str(e)
        }), file=sys.stderr)
        sys.exit(1)
    
    # Prepare result
    result = {
        "secret": secret,
        "socks": socks
    }
    
    # Output JSON
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
