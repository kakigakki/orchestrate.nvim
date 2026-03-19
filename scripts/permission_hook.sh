#!/bin/bash
# Permission hook script for orchestrate.nvim
# This script is called by Claude Code when a permission is required.
# It connects to the Neovim permission server via Unix socket to get user's decision.
#
# Input (stdin): Claude Code PermissionRequest JSON
# {
#   "session_id": "...",
#   "hook_event_name": "PermissionRequest",
#   "tool_name": "Bash",
#   "tool_input": { "command": "..." },
#   ...
# }
#
# Output (stdout): hookSpecificOutput JSON
# {
#   "hookSpecificOutput": {
#     "hookEventName": "PermissionRequest",
#     "decision": { "behavior": "allow" | "deny", ... }
#   }
# }

# Read the socket path from environment variable
SOCKET_PATH="${ORCHESTRATE_PERMISSION_SOCKET:-}"

if [ -z "$SOCKET_PATH" ]; then
  # No socket configured, fall through to default behavior (prompt user)
  exit 0
fi

if [ ! -S "$SOCKET_PATH" ]; then
  # Socket doesn't exist, fall through to default behavior
  exit 0
fi

# Read stdin (permission request JSON from Claude Code)
INPUT=$(cat)

# Send request to Neovim via socket and get response
# Use timeout to avoid hanging indefinitely
RESPONSE=$(echo "$INPUT" | timeout 120 nc -U "$SOCKET_PATH" 2>/dev/null)

if [ -z "$RESPONSE" ]; then
  # No response or timeout, fall through to default behavior
  exit 0
fi

# Output the response (hookSpecificOutput JSON)
echo "$RESPONSE"
exit 0
