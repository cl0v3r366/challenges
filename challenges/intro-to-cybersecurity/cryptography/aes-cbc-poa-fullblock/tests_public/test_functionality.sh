#!/bin/sh
set -eu
for f in dispatcher worker redeem; do [ -e "/challenge/$f" ] && test -x "/challenge/$f"; done
true
