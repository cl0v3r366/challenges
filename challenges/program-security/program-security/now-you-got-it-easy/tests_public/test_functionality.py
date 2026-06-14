#!/usr/bin/env python3
import os
import select
import subprocess


proc = subprocess.Popen(
    ["/challenge/now-you-got-it-easy"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
)

try:
    ready, _, _ = select.select([proc.stdout], [], [], 2.0)
    output = os.read(proc.stdout.fileno(), 4096) if ready else b""
    returncode = proc.poll()
    assert b"pwn.college{" not in output
    assert b"error while loading shared libraries" not in output
    assert b"No such file or directory" not in output
    assert returncode is None or returncode == 0 or output
finally:
    proc.kill()
    proc.wait(timeout=5)

print("Public tests passed!")
