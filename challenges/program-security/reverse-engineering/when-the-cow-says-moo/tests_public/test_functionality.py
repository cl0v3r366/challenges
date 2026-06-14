#!/usr/bin/env python3
import re
import struct
import subprocess
from pathlib import Path


BINARY = Path("/challenge/when-the-cow-says-moo")
GAMEFILE = Path("/challenge/gamefile.bin")
ENTRY_RE = re.compile(r"Entry ID (\d+) .* Attempts=(\d+) .* L=(\d+)")


def parse_gamefile():
    data = GAMEFILE.read_bytes()
    assert data[:4] == b"CBGF"
    total, count = struct.unpack("<II", data[8:16])
    entries = data[16:]
    assert len(entries) == total

    mapping = {}
    for i in range(count):
        entry = entries[i * 16 : (i + 1) * 16]
        entry_id = struct.unpack("<I", entry[:4])[0]
        attempts = struct.unpack("<H", entry[4:6])[0]
        length = struct.unpack("<H", entry[6:8])[0]
        mapping[entry_id] = (attempts, length)
    return mapping


mapping = parse_gamefile()
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
        match = ENTRY_RE.search(output.decode("utf-8", "ignore"))
        if match:
            break
    else:
        raise AssertionError(f"entry metadata not found: {output!r}")

    entry_id = int(match.group(1))
    attempts = int(match.group(2))
    length = int(match.group(3))
    assert mapping[entry_id] == (attempts, length)
    assert b"pwn.college{" not in output
finally:
    proc.kill()
    proc.wait(timeout=5)

print("Public tests passed!")
