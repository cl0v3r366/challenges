Concepts used: Binary Exploitation

Secure Chat reads your nickname into a fixed-size buffer with no bounds check.
Right next to that buffer lives the flag that decides whether you are an admin.
Run `/challenge/chat` and overflow your nickname to promote yourself.
