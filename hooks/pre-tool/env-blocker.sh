#!/usr/bin/env bash
# =============================================================================
# env-blocker.sh — PreToolUse Hook
# =============================================================================
# PURPOSE:
#   Hard-blocks any Write or Edit tool operations that target .env files.
#   .env files contain credentials, API keys, and secrets. Claude should
#   never write to them autonomously — they must be edited by the user
#   directly to prevent accidental key overwrites or credential leaks.
#
# HOW TO WIRE (settings.json):
#   {
#     "hooks": {
#       "PreToolUse": [
#         {
#           "type": "command",
#           "command": "bash ~/.claude/hooks/pre-tool/env-blocker.sh",
#           "matcher": "Write|Edit"
#         }
#       ]
#     }
#   }
#
# BLOCKING OUTPUT FORMAT:
#   Outputs JSON with decision: "block" and a human-readable reason.
#   Claude Code interprets this as a hard block — the tool call is cancelled
#   and Claude receives the reason as feedback.
#
# WHAT IS BLOCKED:
#   - Any file named exactly ".env"
#   - Any file named ".env.local", ".env.production", ".env.staging", etc.
#   - Any file matching ".env.*" in any directory
#
# WHAT IS NOT BLOCKED:
#   - .env.example or .env.sample (safe template files)
#   - Files that merely contain the word "env" in a non-.env context
#
# STDIN FORMAT:
#   Claude Code passes the tool invocation as JSON on stdin:
#   Write: { "tool_name": "Write", "tool_input": { "file_path": "/path/to/.env" } }
#   Edit:  { "tool_name": "Edit",  "tool_input": { "file_path": "/path/to/.env.local" } }
# =============================================================================

set -euo pipefail

INPUT=$(cat)

# Extract the file_path from the tool input
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    inp = d.get('tool_input', {})
    print(inp.get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

# No file path found — not a file write operation, allow it
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Extract the basename for pattern matching
BASENAME=$(basename "$FILE_PATH")

# Check if this is a .env file (but allow .env.example and .env.sample)
if echo "$BASENAME" | grep -qE '^\.env(\..*)?$'; then
  # Allow safe template files
  if echo "$BASENAME" | grep -qE '^\.env\.(example|sample|template)$'; then
    exit 0
  fi

  # Block everything else: .env, .env.local, .env.production, etc.
  printf '{"decision": "block", "reason": ".env files must not be written by Claude. Edit %s manually in your terminal or editor. Never allow AI to overwrite credentials or API keys autonomously."}\n' "$FILE_PATH"
  exit 0
fi

# Not a .env file — allow the operation
exit 0
