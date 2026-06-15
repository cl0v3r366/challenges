#!/bin/bash
set -euo pipefail

test -u /challenge/babyjail_level18
cat > /tmp/smoke.s <<'ASM'
.intel_syntax noprefix
.global _start
_start:
    mov rax, 1
    mov rdi, 1
    lea rsi, [rip + msg]
    mov rdx, 6
    syscall
    ret
msg:
    .ascii "smoke\n"
ASM
gcc -c -nostdlib -fno-pic -o /tmp/smoke.o /tmp/smoke.s
objcopy -O binary --only-section=.text /tmp/smoke.o /tmp/smoke.bin
output=$(/challenge/babyjail_level18 "/proc/$$/ns" < /tmp/smoke.bin)
grep -q 'smoke' <<< "$output"
