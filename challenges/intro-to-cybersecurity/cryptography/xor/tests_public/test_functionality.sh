#!/bin/sh
set -eu
output=$(printf '0\n' | timeout 30 /challenge/run 2>&1 || true)
echo "$output"
echo "$output" | grep -q "The key:"
