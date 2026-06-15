#!/bin/bash
set -euo pipefail

test -u /challenge/babyjail_level14
output=$(printf 'echo smoke; exit\n' | /challenge/babyjail_level14)
grep -q 'smoke' <<< "$output"
grep -q 'FLAG{FAKE}' < <(printf '/bin/cat /flag; exit\n' | /challenge/babyjail_level14)
