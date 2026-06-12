Okay, now we'll try that attack in a slightly more realistic scenario.
Can you remember your SQL to carry out the attack and recover the flag?

----
**HINT:**
Remember that you can make select return chosen plaintext by doing `SELECT 'my_plaintext'`!

This challenge runs a [Flask app](https://flask.palletsprojects.com/en/stable/), so take a moment to inspect how these are configured. Look closely for the route, the request parameter it reads, and the host/port the app binds to.
