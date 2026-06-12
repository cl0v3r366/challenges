#!/bin/sh -e
# Functionality smoke test for the secure-chat family (crypto levels 1/2, pwn
# levels 3/4/5): launching /challenge/chat must print its "=== Secure Chat vN ==="
# banner. We feed one benign line ('q' -- a quit/short-nick/short-message that
# never triggers the intended exploit), then close stdin so the program exits.
# This verifies the entry point runs without performing the attack or leaking the
# flag.
out=$(printf 'q\n' | timeout 30 /challenge/chat 2>&1 || true)
printf '%s\n' "$out"
printf '%s' "$out" | grep -q "=== Secure Chat v"
if printf '%s' "$out" | grep -q "pwn.college{"; then
    echo "FAIL: flag leaked on benign input"
    exit 1
fi
