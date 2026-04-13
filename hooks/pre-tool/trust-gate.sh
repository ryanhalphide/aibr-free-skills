#!/usr/bin/env bash
# =============================================================================
# trust-gate.sh — PreToolUse Hook: Progressive Autonomy via Trust Scores
# =============================================================================
# PURPOSE:
#   Gates autonomous publishing/sending actions based on an accumulated trust
#   score per action type. This is the core mechanism for progressive AI
#   autonomy: start with full human approval for every publish action, then
#   gradually allow automation as trust is demonstrated.
#
#   The pattern solves a real tension: requiring human approval for every
#   action is slow and defeats the purpose of automation. But giving an AI
#   agent full publish autonomy immediately is risky. Trust scores bridge this
#   gap by letting autonomy scale with demonstrated reliability.
#
# HOW IT WORKS:
#   1. Drafting actions (create_draft, edit_draft, etc.) are ALWAYS allowed.
#      Drafts are safe — nothing leaves without explicit publish.
#   2. Publishing/scheduling actions check a trust score from trust.json.
#      If max score across any content-type >= threshold (default: 50), allow.
#      If below threshold, block with instructions to build trust via drafts.
#   3. Email send is ALWAYS blocked regardless of trust score. It requires
#      explicit "send it" confirmation from the user every time.
#   4. Other outbound comms (SMS, notifications, etc.) are ALWAYS blocked.
#
# HOW TO WIRE (settings.json):
#   {
#     "hooks": {
#       "PreToolUse": [
#         {
#           "type": "command",
#           "command": "bash ~/.claude/hooks/pre-tool/trust-gate.sh"
#         }
#       ]
#     }
#   }
#
# TRUST SCORE FILE FORMAT (~/.claude/data/trust.json):
#   {
#     "thresholds": {
#       "routine_auto": 50,    // min score for autonomous publishing
#       "supervised": 25       // min score for supervised (with human review)
#     },
#     "scores": {
#       "platform_a": {
#         "educational": 75,   // well-established, auto-allowed
#         "promotional": 30    // still needs approval
#       },
#       "platform_b": {
#         "educational": 20
#       }
#     }
#   }
#
# HOW TRUST ACCUMULATES:
#   Trust scores are NOT managed by this hook — they are updated by your
#   workflow when a human approves/publishes content. Increment the relevant
#   platform+content-type score on approval, decrement on rejection.
#   A simple approach: +5 per approval, -10 per rejection, cap at 100.
#
# CUSTOMIZATION:
#   - Update the DRAFTING_TOOLS pattern to match your MCP tool name patterns
#   - Update the PUBLISH_TOOLS pattern similarly
#   - Adjust TRUST_FILE path to wherever you store trust scores
#   - Change the threshold in trust.json to tighten/loosen the gate
#
# STDIN FORMAT:
#   Claude Code passes tool invocations as JSON on stdin:
#   { "tool_name": "mcp__publishing__schedule_post", "tool_input": {...} }
# =============================================================================

TRUST_FILE="$HOME/.claude/data/trust.json"

input=$(cat)
tool_name=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null)

# ---------------------------------------------------------------------------
# DRAFTING ACTIONS: ALWAYS ALLOW
# Creating or editing drafts is safe — nothing is published yet.
# Customize the pattern to match your publishing MCP tool names.
# ---------------------------------------------------------------------------
if echo "$tool_name" | grep -qiE "(create_draft|edit_draft|get_draft|list_drafts|delete_draft|get_content|list_content|get_analytics|get_queue_schedule|get_media)"; then
  exit 0
fi

# ---------------------------------------------------------------------------
# PUBLISHING/SCHEDULING ACTIONS: CHECK TRUST SCORE
# These actions have external effect — they publish content to the world.
# Customize the pattern to match your publishing MCP tool names.
# ---------------------------------------------------------------------------
if echo "$tool_name" | grep -qiE "(queue_put|publish|schedule_post|send_post|post_now)"; then
  if [ ! -f "$TRUST_FILE" ]; then
    echo "BLOCKED: Trust score file not found at $TRUST_FILE." >&2
    echo "Cannot auto-publish without the trust system initialized." >&2
    echo "Create drafts for human review to build trust incrementally." >&2
    exit 2
  fi

  # Read the minimum trust threshold for autonomous publishing
  min_threshold=$(python3 -c "
import json, sys
with open('$TRUST_FILE') as f:
    data = json.load(f)
threshold = data.get('thresholds', {}).get('routine_auto', 50)
print(threshold)
" 2>/dev/null)

  # Find the maximum trust score across all platforms and content types
  max_score=$(python3 -c "
import json
with open('$TRUST_FILE') as f:
    data = json.load(f)
scores = data.get('scores', {})
max_s = 0
for platform, types in scores.items():
    for ctype, score in types.items():
        if score > max_s:
            max_s = score
print(max_s)
" 2>/dev/null)

  if [ -z "$max_score" ]; then max_score=0; fi
  if [ -z "$min_threshold" ]; then min_threshold=50; fi

  if [ "$max_score" -ge "$min_threshold" ] 2>/dev/null; then
    # At least one platform/content-type has sufficient trust — allow
    exit 0
  else
    # Trust too low — require human-in-the-loop
    echo "BLOCKED: Trust score too low for autonomous publishing." >&2
    echo "  Current max score: ${max_score} / Threshold: ${min_threshold}" >&2
    echo "  Create drafts and have them approved to accumulate trust." >&2
    echo "  View trust matrix: cat $TRUST_FILE" >&2
    exit 2
  fi
fi

# ---------------------------------------------------------------------------
# EMAIL SEND: ALWAYS BLOCK
# Email has permanent external effect. Requires explicit "send it" from user.
# This is a hard block regardless of trust score.
# ---------------------------------------------------------------------------
if echo "$tool_name" | grep -qiE ".*send.*email|email.*send|gmail.*send|mail.*deliver"; then
  echo "BLOCKED: Email send requires explicit user confirmation ('send it')." >&2
  echo "Never send emails autonomously. Present the draft and wait for approval." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# OTHER OUTBOUND COMMS: ALWAYS BLOCK
# SMS, push notifications, Slack messages, webhooks, etc.
# ---------------------------------------------------------------------------
if echo "$tool_name" | grep -qiE "mcp__.*(send_message|sms|outbound|notify|message_send|deliver|send_chat|push_notification)"; then
  echo "BLOCKED: Outbound communication tool detected: $tool_name" >&2
  echo "Never send messages without explicit user confirmation." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# EVERYTHING ELSE: ALLOW
# ---------------------------------------------------------------------------
exit 0
