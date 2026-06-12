Concepts used: Cryptography

Secure Chat encrypts its session transcript with a XOR stream cipher.
A stream cipher is only as secret as its keystream, and this one hands the keystream right back to you.
Run `/challenge/chat`, recover the keystream, and decrypt the transcript to read the flag.
