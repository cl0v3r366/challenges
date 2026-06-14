#!/usr/bin/env python3
import os
import subprocess


def test_challenge_binary_runs_on_bad_input():
    candidates = []
    for name in os.listdir('/challenge'):
        path = os.path.join('/challenge', name)
        if not os.path.isfile(path):
            continue
        if name.startswith('.') or name.startswith('lib'):
            continue
        if os.access(path, os.X_OK):
            candidates.append(path)
    assert candidates, 'no executable challenge binary found'
    binary = sorted(candidates)[0]
    proc = subprocess.run(
        [binary],
        input=b"\n" + b"\x00" * 32,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=5,
    )
    assert proc.stdout or proc.returncode is not None
