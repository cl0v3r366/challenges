Concepts used: Cryptography

The members board encrypts your message together with a secret notice using AES in ECB mode.
ECB encrypts identical plaintext blocks to identical ciphertext blocks, which leaks far more than it should.
Run `/challenge/chat` and use the chosen-prefix encryptions to peel the secret notice out one byte at a time.
