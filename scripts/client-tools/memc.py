#!/usr/bin/env python3
"""Send one command to memd and print the reply."""
import socket
import sys

import os
SOCK = os.environ.get("MEMD_SOCK", "/tmp/opencode/memd.sock")

with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
    s.settimeout(600)
    s.connect(SOCK)
    s.sendall((" ".join(sys.argv[1:]) + "\n").encode())
    f = s.makefile("r")
    while True:
        line = f.readline()
        if not line or line.strip() in ("END",):
            break
        print(line.rstrip())
