#!/usr/bin/env python3
import os
import subprocess
from pathlib import Path


def challenge_binary() -> Path:
    candidates = []
    for path in Path("/challenge").iterdir():
        if not path.is_file() or path.name.startswith("."):
            continue
        if os.access(path, os.X_OK):
            candidates.append(path)
    assert candidates, "no executable challenge binary found"
    return sorted(candidates)[0]


binary = challenge_binary()
run = subprocess.run(
    [str(binary)],
    input=b"quit\n",
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    timeout=5,
)
assert run.stdout, "challenge produced no output"
assert b"pwn.college{" not in run.stdout
assert b"error while loading shared libraries" not in run.stdout
assert b"No such file or directory" not in run.stdout
print("Public tests passed!")
