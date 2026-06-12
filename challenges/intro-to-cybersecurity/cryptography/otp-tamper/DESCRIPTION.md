So, the One Time Pad is proven to be secure... but only in the _Confidential_ sense!
It actually does not guarantee anything about Integrity: since XOR is self-inverse, the same operation is used for encryption and decryption. This direct relationship means a known plaintext-ciphertext pair reveals the key.

This challenge asks you: what if you could _tamper_ with the message in transit? Before you _run_ to craft your solution, it will be worth taking a close look at the /challenge ahead.

Think about how XOR works, and see if you can get the flag!
