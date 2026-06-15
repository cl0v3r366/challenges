#!/bin/bash
set -euo pipefail

test -u /challenge/babyjail_level16
output=$(printf 'echo smoke; exit\n' | /challenge/babyjail_level16)
grep -q 'smoke' <<< "$output"
