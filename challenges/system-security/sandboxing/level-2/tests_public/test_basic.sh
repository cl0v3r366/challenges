#!/bin/bash
set -euo pipefail

test -u /challenge/babyjail_level2
printf '\xc3' | /challenge/babyjail_level2 /
