"""Talk to the running Blender MCP addon (localhost:9876) without an MCP client.

Usage:
  python bl_client.py info                      # scene info
  python bl_client.py exec path/to/script.py    # run a Python script inside the live Blender session
  python bl_client.py eval "print(bpy.app.version_string)"
Blender must be open with 'MCP for Blender' enabled and its server started.
"""
from __future__ import annotations

import json
import socket
import sys

HOST, PORT = "127.0.0.1", 9876


def call(cmd_type: str, params: dict | None = None, timeout: float = 120.0) -> dict:
    s = socket.create_connection((HOST, PORT), timeout=10)
    s.settimeout(timeout)
    s.sendall(json.dumps({"type": cmd_type, "params": params or {}}).encode())
    data = b""
    while True:
        chunk = s.recv(1 << 20)
        if not chunk:
            break
        data += chunk
        try:
            return json.loads(data.decode())
        except ValueError:
            continue
    return json.loads(data.decode())


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        return
    op = sys.argv[1]
    if op == "info":
        print(json.dumps(call("get_scene_info"), indent=2))
    elif op == "exec":
        code = open(sys.argv[2], encoding="utf-8").read()
        print(json.dumps(call("execute_code", {"code": code}), indent=2))
    elif op == "eval":
        print(json.dumps(call("execute_code", {"code": sys.argv[2]}), indent=2))
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
