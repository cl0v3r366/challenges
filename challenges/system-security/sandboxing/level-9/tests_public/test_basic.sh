#!/bin/bash
set -euo pipefail

test -u /challenge/babyjail_level9
cat > /tmp/smoke.s <<'ASM'
.intel_syntax noprefix
.global _start
_start:
    lea ecx, [rip + msg]
    mov edx, 6
    mov ebx, 1
    mov eax, 4
    int 0x80
msg:
    .ascii "smoke\n"
ASM
gcc -c -nostdlib -fno-pic -o /tmp/smoke.o /tmp/smoke.s
objcopy -O binary --only-section=.text /tmp/smoke.o /tmp/smoke.bin
set +e
output=$(/challenge/babyjail_level9 < /tmp/smoke.bin)
set -e
grep -q 'smoke' <<< "$output"
