#!/bin/bash
gcc -fno-pie -no-pie -z execstack -masm=intel -fno-stack-protector $1
