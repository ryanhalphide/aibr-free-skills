#!/usr/bin/env bash
# =============================================================================
# memory-extract.sh — Stop Hook: AI-Powered Session Memory Extraction
# =============================================================================
# PURPOSE:
#   When a Claude Code session ends, this hook reads the session transcript,
#   calls the Claude Haiku API to extract genuinely novel insights (fixes,
#   decisions, patterns, tool learnings), and appends them to a daily memory
#   file. Future sessions can load this memory at startup, creating compound
#   knowledge that grows over time.
#
#   This is the "Stop" half of the memory pipeline. The "load" half happens
#   in SessionStart hooks that inject memory file contents into additionalContext.
#
# HOW TO WIRE (settings.json):
#   {
#     "hooks": {
#       "Stop": [
#         { "type": "command", "command": "bash ~/.claude/hooks/stop/memory-extract.sh" }
#       ]
#     }
#   }
#
# DEPENDENCIES:
#   - ANTHROPIC_API_KEY environment variable (or discoverable from a local .env)
#   - jq (brew install jq)
#   - curl
#   - python3
#
# OUTPUT:
#   Appends extracted insights to: ~/.claude/memories/auto-YYYYMMDD.md
#   Format:
#     ## Session <session_id> (<timestamp>)
#     - [fix] description of what was fixed
#     - [decision] architecture decision made
#     - [pattern] reusable pattern discovered
#     - [tool] how a specific tool behaves
#     - [warning] known gotcha or failure mode
#
# WHAT IS WORTH EXTRACTING (via Haiku prompt):
#   - Bugs that were fixed and WHY they occurred
#   - Decisions made that aren't obvious from the code
#   - Newly discovered tool behaviors or API quirks
#   - Patterns that proved effective (or ineffective)
#   - Warning: gotchas that could trip you up again
#
# WHAT IS NOT EXTRACTED:
#   - Routine code edits (those are in git)
#   - Status updates and progress notes
#   - Information already documented in CLAUDE.md
#   - Anything that can be derived by reading the current code
#
# GUARDS:
#   - Only runs if transcript has >= 20 lines (skip trivial sessions)
#   - Creates a lock file per session to prevent duplicate extraction
#   - Skips if no API key is found
#   - If Haiku returns "SKIP", nothing is written (silent no-op)
#
# STDIN FORMAT:
#   { "session_id": "abc123", "transcript_path": "/path/to/transcript.jsonl" }
# =============================================================================

set -euo pipefail

INPUT=$(cat 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)

# Memory storage directory
MEMORY_DIR="$HOME/.claude/memories"
TODAY=$(date +%Y%m%d)
MEMORY_FILE="$MEMORY_DIR/auto-${TODAY}.md"

mkdir -p "$MEMORY_DIR"

# ---------------------------------------------------------------------------
# Locate the session transcript
# ---------------------------------------------------------------------------
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  # Try constructing path from session_id (Claude Code stores transcripts here)
  if [ -n "$SESSION_ID" ]; then
    # Adjust this path to match your Claude Code installation
    TRANSCRIPT_PATH="$HOME/.claude/projects/$(basename "$PWD" | tr '/' '-')/${SESSION_ID}.jsonl"
  fi
fi

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0  # No transcript available
fi

# Guard: only extract from sessions with meaningful content
LINE_COUNT=$(wc -l < "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)
if [ "$LINE_COUNT" -lt 20 ]; then
  exit 0
fi

# Guard: don't extract twice for the same session
LOCK_FILE="$MEMORY_DIR/.extracted-${SESSION_ID}"
if [ -f "$LOCK_FILE" ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Extract the last 200 assistant messages from the transcript
# (Trimmed to 300 chars each to stay within Haiku's context budget)
# ---------------------------------------------------------------------------
SUMMARY=$(tail -200 "$TRANSCRIPT_PATH" 2>/dev/null | \
  python3 -c "
import sys, json
lines = []
for line in sys.stdin:
    try:
        obj = json.loads(line.strip())
        role = obj.get('role', '')
        if role == 'assistant':
            content = obj.get('content', '')
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'text':
                        text = c.get('text', '')[:300]
                        if text.strip():
                            lines.append(text.strip())
            elif isinstance(content, str) and content.strip():
                lines.append(content.strip()[:300])
    except Exception:
        pass
# Return the last 30 meaningful assistant messages
print('\n---\n'.join(lines[-30:]))
" 2>/dev/null || true)

if [ -z "$SUMMARY" ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Find the Anthropic API key
# ---------------------------------------------------------------------------
API_KEY="${ANTHROPIC_API_KEY:-}"
if [ -z "$API_KEY" ]; then
  # Try common local .env locations as fallback
  for env_file in \
    "$HOME/Code/your-project/.env" \
    "$HOME/.env" \
    "$PWD/.env"; do
    if [ -f "$env_file" ]; then
      FOUND_KEY=$(grep 'ANTHROPIC_API_KEY' "$env_file" 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'" | tr -d ' ' || true)
      if [ -n "$FOUND_KEY" ]; then
        API_KEY="$FOUND_KEY"
        break
      fi
    fi
  done
fi

if [ -z "$API_KEY" ]; then
  exit 0  # No API key available — skip silently
fi

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ---------------------------------------------------------------------------
# Call Claude Haiku to extract novel insights
# Haiku is used here deliberately: it's cheap, fast, and sufficient for
# extraction tasks. Save Opus/Sonnet for actual work.
# ---------------------------------------------------------------------------
INSIGHTS=$(curl -s -X POST "https://api.anthropic.com/v1/messages" \
  -H "x-api-key: $API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "$(jq -n --arg summary "$SUMMARY" '{
    model: "claude-haiku-4-5",
    max_tokens: 500,
    messages: [{
      role: "user",
      content: ("From this Claude Code session excerpt, extract 1-3 SHORT memory entries worth keeping for future sessions. Focus on: bugs fixed (and root cause), decisions made that are not obvious from code, tool behaviors discovered, patterns that worked or failed. ONLY capture genuinely novel knowledge. Format each as: \"- [type] description\" where type is one of: fix|decision|pattern|tool|warning. If nothing notable to extract, output exactly: SKIP\n\nSession excerpt:\n" + $summary)
    }]
  }') \
  2>/dev/null | jq -r '.content[0].text // "SKIP"' 2>/dev/null || echo "SKIP")

# Nothing worth saving
if [ "$INSIGHTS" = "SKIP" ] || [ -z "$INSIGHTS" ]; then
  touch "$LOCK_FILE"
  exit 0
fi

# ---------------------------------------------------------------------------
# Append insights to today's memory file
# ---------------------------------------------------------------------------
{
  echo ""
  echo "## Session ${SESSION_ID} (${TIMESTAMP})"
  echo "$INSIGHTS"
} >> "$MEMORY_FILE"

# Mark this session as extracted (prevent duplicate runs)
touch "$LOCK_FILE"

exit 0
