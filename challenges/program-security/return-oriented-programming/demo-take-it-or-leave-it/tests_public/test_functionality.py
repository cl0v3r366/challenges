#!/usr/bin/env python3
from pathlib import Path
import subprocess

root = Path('/challenge')
assert (root / 'take-it-or-leave-it.c').exists()
assert (root / 'take-it-or-leave-it').exists()
assert (root / 'take-it-or-leave-it').stat().st_mode & 0o111
out = subprocess.run([str(root / 'take-it-or-leave-it')], input=b'A' * 16, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=5).stdout
assert out
print('Public tests passed!')
