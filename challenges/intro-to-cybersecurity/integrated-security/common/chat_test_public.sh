#!/usr/bin/env python3
import os
import pathlib
import socket
import subprocess
import time

import requests


assert pathlib.Path("/challenge/run").is_file()
assert os.access("/challenge/run", os.X_OK)
assert pathlib.Path("/challenge/chat-server").is_file()
assert os.access("/challenge/chat-server", os.X_OK)
assert not pathlib.Path("/challenge/chat").exists()

if pathlib.Path("/challenge/check-admin-pin").exists():
    assert os.access("/challenge/check-admin-pin", os.X_OK)

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]

env = {
    **os.environ,
    "CHAT_HOST": "127.0.0.1",
    "CHAT_PORT": str(port),
    "DB_PATH": f"/tmp/secure-chat-smoke-{os.getpid()}.db",
}
proc = subprocess.Popen(["/challenge/chat-server"], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    deadline = time.time() + 10
    while time.time() < deadline:
        try:
            response = requests.get(f"http://127.0.0.1:{port}/", timeout=1)
            break
        except requests.RequestException:
            time.sleep(0.1)
    else:
        raise AssertionError("chat-server did not start")

    assert response.status_code == 200
    assert "/login" in response.text
    assert "/register" in response.text
    print("PASS")
finally:
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=5)
