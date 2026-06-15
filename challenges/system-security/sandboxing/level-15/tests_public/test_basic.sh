#!/bin/bash
set -euo pipefail

test -u /challenge/babyjail_level15
output=$(printf 'echo smoke; exit\n' | /challenge/babyjail_level15)
grep -q 'smoke' <<< "$output"
