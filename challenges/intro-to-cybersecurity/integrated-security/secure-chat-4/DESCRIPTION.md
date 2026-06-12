Concepts used: Binary Exploitation

This time the overflow is in the message buffer, and the admin console is never called on its own.
But the function it returns into is stored on the stack, right past the end of that buffer.
Run `/challenge/chat`, overwrite the saved return address, and redirect execution into the admin console.
