#!/bin/bash
set -euo pipefail

test -u /challenge/babyrace_level5_1
grep -q 'path contains `flag`' < <(/challenge/babyrace_level5_1 /flag || true)
rm -rf /home/hacker/check
mkdir -p /home/hacker/check
touch /home/hacker/check/file
grep -q 'directory not owned by root' < <(/challenge/babyrace_level5_1 /home/hacker/check/file || true)
