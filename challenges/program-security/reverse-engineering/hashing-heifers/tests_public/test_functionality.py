#!/usr/bin/env python3
import re
import subprocess
from pathlib import Path


BINARY = Path("/challenge/hashing-heifers")
GAMEFILE = Path("/challenge/gamefile.bin")
ENTRY_RE = re.compile(rb"Entry ID \d+ .* Attempts=\d+ .* L=\d+")


assert GAMEFILE.read_bytes()[:4] == b"CBGF"
proc = subprocess.Popen(
    [str(BINARY)],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
)

try:
    output = b""
    while len(output) < 4096:
        chunk = proc.stdout.read(1)
        assert chunk, f"binary exited before printing entry metadata: {output!r}"
        output += chunk
        if ENTRY_RE.search(output):
            break
    else:
        raise AssertionError(f"entry metadata not found: {output!r}")

    assert b"pwn.college{" not in output
finally:
    proc.kill()
    proc.wait(timeout=5)

print("Public tests passed!")
