#!/usr/bin/env python3
"""Send JSON commands to a running game's AutomationBridge and print replies.

The game must be launched with PPTCG_AUTOMATION=1 in its environment.

Usage:
    automation_client.py ping
    automation_client.py screenshot /abs/path/out.png
    automation_client.py key E [press|release]
    automation_client.py click 640 400 [left|right]
    automation_client.py mouse_move 640 400
    automation_client.py raw '{"cmd": "ping"}'
"""
import json
import socket
import sys

HOST = "127.0.0.1"
PORT = 8765


def send(payload: dict) -> dict:
    with socket.create_connection((HOST, PORT), timeout=5) as sock:
        sock.sendall((json.dumps(payload) + "\n").encode("utf-8"))
        sock.settimeout(5)
        data = sock.recv(65536)
    return json.loads(data.decode("utf-8").strip().splitlines()[0])


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]
    args = sys.argv[2:]

    if cmd == "ping":
        payload = {"cmd": "ping"}
    elif cmd == "screenshot":
        payload = {"cmd": "screenshot", "path": args[0]}
    elif cmd == "key":
        payload = {"cmd": "key", "keycode": args[0], "action": args[1] if len(args) > 1 else "press"}
    elif cmd == "click":
        payload = {"cmd": "click", "x": float(args[0]), "y": float(args[1]),
                   "button": args[2] if len(args) > 2 else "left"}
    elif cmd == "mouse_move":
        payload = {"cmd": "mouse_move", "x": float(args[0]), "y": float(args[1])}
    elif cmd == "raw":
        payload = json.loads(args[0])
    else:
        print(f"unknown command: {cmd}")
        sys.exit(1)

    print(json.dumps(send(payload)))


if __name__ == "__main__":
    main()
