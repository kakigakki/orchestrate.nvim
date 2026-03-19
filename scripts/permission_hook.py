#!/usr/bin/env python3
"""
Permission hook script for orchestrate.nvim
This script is called by Claude Code when a permission is required.
It connects to the Neovim permission server via Unix socket to get user's decision.

Input (stdin): Claude Code PermissionRequest JSON
Output (stdout): hookSpecificOutput JSON
"""

import json
import os
import socket
import sys

# Debug log file
DEBUG_LOG = os.path.expanduser("~/.cache/orchestrate_hook_debug.log")


def log_debug(msg):
    """Write debug message to log file."""
    try:
        with open(DEBUG_LOG, "a") as f:
            import datetime
            ts = datetime.datetime.now().isoformat()
            f.write(f"[{ts}] {msg}\n")
    except Exception:
        pass


def main():
    log_debug("Hook script started")

    # Read the socket path from environment variable
    socket_path = os.environ.get("ORCHESTRATE_PERMISSION_SOCKET", "")
    log_debug(f"Socket path: {socket_path}")

    if not socket_path:
        log_debug("No socket path configured, exiting")
        sys.exit(0)

    if not os.path.exists(socket_path):
        log_debug(f"Socket does not exist: {socket_path}")
        sys.exit(0)

    # Read stdin (permission request JSON from Claude Code)
    try:
        input_data = sys.stdin.read()
        log_debug(f"Received input: {input_data[:200]}...")
    except Exception as e:
        log_debug(f"Failed to read stdin: {e}")
        sys.exit(0)

    if not input_data.strip():
        log_debug("Empty input, exiting")
        sys.exit(0)

    # Connect to Neovim permission server
    try:
        log_debug("Connecting to socket...")
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(120)  # 2 minute timeout
        sock.connect(socket_path)
        log_debug("Connected to socket")

        # Send the request
        sock.sendall((input_data.strip() + "\n").encode("utf-8"))
        log_debug("Sent request to Neovim")

        # Receive the response
        response = b""
        while True:
            log_debug("Waiting for response...")
            chunk = sock.recv(4096)
            if not chunk:
                log_debug("Received EOF")
                break
            response += chunk
            log_debug(f"Received chunk: {len(chunk)} bytes")
            if b"\n" in response:
                log_debug("Found newline, breaking")
                break

        sock.close()
        log_debug(f"Response: {response}")

        if response:
            output = response.decode("utf-8").strip()
            log_debug(f"Outputting: {output}")
            print(output)
            sys.exit(0)
        else:
            log_debug("Empty response")

    except socket.timeout:
        log_debug("Socket timeout")
        sys.exit(0)
    except Exception as e:
        log_debug(f"Exception: {e}")
        sys.exit(0)

    log_debug("Exiting with default behavior")
    sys.exit(0)


if __name__ == "__main__":
    main()
