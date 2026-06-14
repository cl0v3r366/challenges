#!/usr/bin/env python3
import os
import select
import subprocess
from pathlib import Path


def challenge_binary():
    candidates = []
    for path in Path("/challenge").iterdir():
        if not path.is_file():
            continue
        if path.name.startswith(".") or path.name in {"libcapstone.so.5", "libc.so.6", "libc.so.6.remote", "libdl.so.2", "ld-linux-x86-64.so.2"}:
            continue
        if os.access(path, os.X_OK):
            candidates.append(path)
    assert candidates, "no executable challenge binary found"
    return sorted(candidates)[0]


binary = challenge_binary()
proc = subprocess.Popen(
    [str(binary)],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
)
try:
    ready, _, _ = select.select([proc.stdout], [], [], 2.0)
    output = os.read(proc.stdout.fileno(), 4096) if ready else b""
    assert b"pwn.college{" not in output
    assert b"error while loading shared libraries" not in output
    assert b"No such file or directory" not in output
    assert proc.poll() is None or proc.returncode == 0 or output
finally:
    proc.kill()
    proc.wait(timeout=5)

print("Public tests passed!")
