#!/usr/bin/env bash
# =============================================================================
# context-budget-warn.sh — PostToolUse Hook
# =============================================================================
# PURPOSE:
#   Tracks the total number of tool calls made in the current session and
#   emits progressive warnings at 50 / 100 / 150 calls. These warnings
#   remind Claude (and the user) to consider running /compact or /refresh
#   before the context window becomes saturated and quality degrades.
#
#   Large sessions without compaction cause: repeated information in context,
#   Claude losing track of earlier decisions, slower responses, and
#   eventually hitting the context limit mid-task.
#
# HOW TO WIRE (settings.json):
#   {
#     "hooks": {
#       "PostToolUse": [
#         {
#           "type": "command",
#           "command": "bash ~/.claude/hooks/post-tool/context-budget-warn.sh"
#         }
#       ]
#     }
#   }
#
# BEHAVIOR:
#   - Silent at all non-threshold tool counts (no overhead)
#   - Prints a one-line warning at 50, 100, and 150 tool calls
#   - Counter is stored in /tmp per-session (auto-cleaned on reboot)
#   - Session is identified by session_id from Claude's JSON, falling back to PPID
#
# CUSTOMIZATION:
#   Change the thresholds in the case statement below.
#   Add additional thresholds or change the warning messages as needed.
#
# STDIN FORMAT:
#   { "session_id": "abc123", ... }
# =============================================================================

INPUT=$(cat 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

# Fall back to PPID if session_id not available
if [ -z "$SESSION_ID" ]; then
  SESSION_ID="pid-$PPID"
fi

COUNTER_FILE="/tmp/claude-tool-count-${SESSION_ID}"

# Initialize or increment the per-session counter
if [ -f "$COUNTER_FILE" ]; then
  COUNT=$(($(cat "$COUNTER_FILE") + 1))
else
  COUNT=1
fi
echo "$COUNT" > "$COUNTER_FILE"

# Emit warnings at thresholds
case "$COUNT" in
  50)
    echo "[CONTEXT-BUDGET] 50 tool calls this session. Consider /refresh or /compact if context feels heavy."
    ;;
  100)
    echo "[CONTEXT-BUDGET] 100 tool calls. Strongly recommend /refresh + /compact to free context window."
    ;;
  150)
    echo "[CONTEXT-BUDGET] 150 tool calls. Context is likely saturated. Run /compact now or quality will degrade."
    ;;
  200)
    echo "[CONTEXT-BUDGET] WARNING: 200 tool calls. Immediate /compact required. Consider starting a fresh session for remaining tasks."
    ;;
esac

exit 0
