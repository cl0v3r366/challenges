#!/bin/bash
set -euo pipefail

test -u /challenge/babyrace_level4_0
grep -q 'path contains `flag`' < <(/challenge/babyrace_level4_0 /flag || true)
ln -sf /flag /home/hacker/link
grep -q 'file is a symlink' < <(/challenge/babyrace_level4_0 /home/hacker/link || true)
python3 - <<'PY'
open('/home/hacker/large', 'wb').write(b'A' * 257)
PY
grep -q 'file is too large' < <(/challenge/babyrace_level4_0 /home/hacker/large || true)
