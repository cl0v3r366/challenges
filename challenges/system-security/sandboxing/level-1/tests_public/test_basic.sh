#!/bin/bash
set -euo pipefail

test -u /challenge/babyjail_level1
/challenge/babyjail_level1 /flag | grep -q 'FLAG{FAKE}'
