#!/usr/bin/env python3
import signal
import subprocess
import tempfile
import time
from pathlib import Path


def asm_to_shellcode(asm: str) -> bytes:
    with tempfile.TemporaryDirectory() as td:
        src = Path(td) / "code.s"
        obj = Path(td) / "code.o"
        raw = Path(td) / "code.bin"
        src.write_text(asm)
        subprocess.run(["gcc", "-c", "-nostdlib", "-fno-pic", "-o", obj, src], check=True)
        subprocess.run(["objcopy", "-O", "binary", "--only-section=.text", obj, raw], check=True)
        return raw.read_bytes()


shellcode = asm_to_shellcode(
    """
    .intel_syntax noprefix
    .global _start
    _start:
        mov qword ptr [rip + ts], 0
        mov qword ptr [rip + ts + 8], 50000000
        lea rdi, [rip + ts]
        xor esi, esi
        mov eax, 35
        syscall
        int3
    ts:
        .quad 0, 0
    """
)

start = time.monotonic()
proc = subprocess.run(
    ["/challenge/babyjail_level11", "/dev/null"],
    input=shellcode,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)
elapsed = time.monotonic() - start
assert proc.returncode == -signal.SIGTRAP
assert elapsed > 0.03
