#!/usr/bin/env python3
import os
import subprocess


def test_demo_sources_and_builds():
    for path in [
        "/challenge/canary-linear.c",
        "/challenge/canary-ptr.c",
        "/challenge/canary-recurse.c",
        "/challenge/build_no_canary.sh",
        "/challenge/build_w_canary.sh",
        "/challenge/build_no_canary_yes_pie.sh",
        "/challenge/build_w_canary_and_pie.sh",
    ]:
        assert os.path.exists(path), path

    for path in [
        "/challenge/canary-linear-no-canary",
        "/challenge/canary-linear-canary",
        "/challenge/canary-linear-no-canary-pie",
        "/challenge/canary-linear-canary-pie",
    ]:
        assert os.access(path, os.X_OK), path

    canary_symbols = subprocess.check_output(
        ["readelf", "-sW", "/challenge/canary-linear-canary"],
        text=True,
    )
    assert "__stack_chk_fail" in canary_symbols

    no_canary_symbols = subprocess.check_output(
        ["readelf", "-sW", "/challenge/canary-linear-no-canary"],
        text=True,
    )
    assert "__stack_chk_fail" not in no_canary_symbols

    pie_type = subprocess.check_output(
        ["readelf", "-h", "/challenge/canary-linear-canary-pie"],
        text=True,
    )
    assert "DYN" in pie_type
