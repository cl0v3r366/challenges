#!/usr/bin/env python3
import subprocess
import tempfile
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
        mov edi, 7
        mov eax, 60
        syscall
    """
)

proc = subprocess.run(
    ["/challenge/babyjail_level10", "/dev/null"],
    input=shellcode,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)
assert proc.returncode == 7
