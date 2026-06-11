#!/bin/sh
# Functionality smoke test: the challenge program should run and present its
# banner.  It must NOT hand over the flag without the intended exploitation.
set -eu

output=$(timeout 30 /challenge/run </dev/null 2>&1 || true)
echo "$output"

echo "$output" | grep -q "Welcome to Access Control"
