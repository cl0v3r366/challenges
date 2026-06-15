#!/bin/bash
set -euo pipefail

test -u /challenge/babyjail_level3
printf '\xc3' | /challenge/babyjail_level3 /
