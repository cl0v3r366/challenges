#!/bin/bash
set -euo pipefail

test -u /challenge/babyrace_level1_1
grep -q 'path contains `flag`' < <(/challenge/babyrace_level1_1 /flag || true)
ln -sf /flag /home/hacker/link
grep -q 'file is a symlink' < <(/challenge/babyrace_level1_1 /home/hacker/link || true)
