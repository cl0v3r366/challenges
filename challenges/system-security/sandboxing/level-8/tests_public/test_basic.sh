#!/bin/bash
set -euo pipefail

test -u /challenge/babyjail_level8
cat > /tmp/smoke.s <<'ASM'
.intel_syntax noprefix
.global _start
_start:
    mov rax, 1
    mov rdi, 1
    lea rsi, [rip + msg]
    mov rdx, 6
    syscall
msg:
    .ascii "smoke\n"
ASM
gcc -c -nostdlib -fno-pic -o /tmp/smoke.o /tmp/smoke.s
objcopy -O binary --only-section=.text /tmp/smoke.o /tmp/smoke.bin
set +e
output=$(/challenge/babyjail_level8 < /tmp/smoke.bin)
set -e
grep -q 'smoke' <<< "$output"
