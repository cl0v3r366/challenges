#!/bin/bash
set -euo pipefail

test -u /challenge/babyrace_level1_0
grep -q 'path contains `flag`' < <(/challenge/babyrace_level1_0 /flag || true)
ln -sf /flag /home/hacker/link
grep -q 'file is a symlink' < <(/challenge/babyrace_level1_0 /home/hacker/link || true)
