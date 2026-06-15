#!/bin/bash
set -euo pipefail

test -e /challenge/babykernel_level1.0.ko
rm -f /tmp/pwncollege-disable-kvm
vm restart
vm exec 'test -e /proc/pwncollege && dd if=/proc/pwncollege bs=10 count=1 status=none' | grep -q 'password:'
