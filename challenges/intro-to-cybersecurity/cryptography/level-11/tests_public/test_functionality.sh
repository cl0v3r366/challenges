#!/bin/sh
set -eu
test -x /challenge/run
timeout 15 /challenge/run </dev/null >/dev/null 2>&1 || true
