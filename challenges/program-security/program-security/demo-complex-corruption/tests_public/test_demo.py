#!/usr/bin/env python3
import os
import subprocess


def test_demo_assets_and_binary():
    for path in [
        "/challenge/corruptable_cat.c",
        "/challenge/grade_calc.c",
        "/challenge/poc.py",
        "/challenge/leak_file",
        "/challenge/canary_file",
        "/challenge/exploit_file",
        "/challenge/build.sh",
    ]:
        assert os.path.exists(path), path

    assert os.access("/challenge/corruptable_cat", os.X_OK)

    proc = subprocess.run(
        ["/challenge/corruptable_cat"],
        input=b"EXIT\n",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=5,
    )
    assert proc.returncode == 0
    assert b"filename (or EXIT):" in proc.stdout
