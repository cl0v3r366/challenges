#!/bin/sh
# Functionality smoke test for the decrypt-overflow family.
#
# The challenge ships two SUID binaries that share a per-instance secret AES key
# (/challenge/.key, generated at container start):
#   - /challenge/dispatch          : AES-128-ECB oracle, prints ECB("VERIFIED"+p64(len)+pad(msg))
#   - /challenge/vulnerable-overflow: decrypts an attacker-supplied ciphertext into an
#                                     undersized buffer; only prints "Decrypted message:"
#                                     once a *forged* VERIFIED block is supplied.
#
# We exercise both entry points on benign input WITHOUT solving the overflow and
# WITHOUT printing the flag.  The oracle is the cleanly observable component, so we
# assert its concrete contract (a fixed-size ciphertext block for a known message);
# the vulnerable binary is exercised on a bogus ciphertext that it rejects, and we
# assert it leaks neither the flag nor the post-verification success line.
set -eu

test -x /challenge/dispatch
test -x /challenge/vulnerable-overflow

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The flag must never appear on any benign path checked below.
assert_no_flag() {
    if grep -q "pwn.college{" "$1"; then
        echo "FAIL: flag leaked on benign path" >&2
        exit 1
    fi
}

# 1) The ECB oracle: a 5-byte message yields plaintext "VERIFIED"(8) + p64(len)(8) +
#    msg(5) = 21 bytes, PKCS7-padded to 32 bytes = exactly two AES blocks.  Asserting
#    the exact length proves the oracle read the key and encrypted, without revealing
#    any plaintext.  (Ciphertext is binary, so capture to a file rather than $(...),
#    which would strip trailing newline bytes and corrupt the length.)
printf 'hello' | timeout 30 /challenge/dispatch > "$tmp/oracle" 2>/dev/null || true
assert_no_flag "$tmp/oracle"
oracle_len=$(wc -c < "$tmp/oracle")
if [ "$oracle_len" -ne 32 ]; then
    echo "FAIL: dispatch produced ${oracle_len} bytes, expected 32" >&2
    exit 1
fi

# 2) The vulnerable binary: feed a correctly-sized (32-byte) but bogus ciphertext.
#    It fails the "VERIFIED" header check and aborts before the decrypt-success path,
#    so it must print neither the flag nor "Decrypted message:".
# (Capture to a file, not stdout: the rejected-decrypt output is binary and would
# break pwnshop's UTF-8 capture of this test's stdout.)
head -c 32 /dev/zero | timeout 30 /challenge/vulnerable-overflow > "$tmp/vuln" 2>&1 || true
assert_no_flag "$tmp/vuln"
if grep -q "Decrypted message:" "$tmp/vuln"; then
    echo "FAIL: vulnerable-overflow accepted a forged-free ciphertext" >&2
    exit 1
fi

echo "OK: decrypt-overflow functionality verified"
