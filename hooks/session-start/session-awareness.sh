#!/bin/bash
# =============================================================================
# session-awareness.sh — SessionStart Hook
# =============================================================================
# PURPOSE:
#   Detects all other running Claude Code sessions on this machine, cleans up
#   stale session records, shows cross-session context at startup, and registers
#   the current session into the shared state layer.
#
# HOW TO WIRE (settings.json):
#   {
#     "hooks": {
#       "SessionStart": [
#         { "type": "command", "command": "bash ~/.claude/hooks/session-start/session-awareness.sh" }
#       ]
#     }
#   }
#
# DEPENDENCIES:
#   - jq (brew install jq)
#   - Shared state dir at ~/.claude/shared-state/sessions/
#   - Optional: ~/.claude/hive/config.json for multi-agent hive awareness
#   - Optional: ~/.claude/shared-state/event-log.jsonl for cross-session event log
#
# MULTI-SESSION COORDINATION:
#   Each session writes a JSON file to the shared sessions dir with its PID,
#   current working directory, project name, heartbeat timestamp, and active
#   task summary. On next SessionStart, stale sessions are pruned (dead PID,
#   heartbeat >30min, or zero-tool ghost >5min), then all active sessions are
#   displayed. This prevents two terminals from unknowingly working on the same
#   files simultaneously.
#
# CUSTOMIZATION:
#   Update get_project_name() to map your repo paths to friendly names.
# =============================================================================

SESSIONS_DIR="$HOME/.claude/shared-state/sessions"
HIVE_CONFIG="$HOME/.claude/hive/config.json"
CLAUDE_PID="$PPID"
SESSION_ID="term-${CLAUDE_PID}"

mkdir -p "$SESSIONS_DIR"

# ---------------------------------------------------------------------------
# Map absolute directory path → friendly project name.
# Add your own repo paths here.
# ---------------------------------------------------------------------------
get_project_name() {
  case "$1" in
    */your-project*) echo "YourProject" ;;
    # Add more mappings:
    # */my-api*) echo "My API" ;;
    # */client-x*) echo "Client X" ;;
    *) basename "$1" ;;
  esac
}

# ---------------------------------------------------------------------------
# Calculate human-readable relative time from an ISO-8601 UTC timestamp.
# Works on macOS (BSD date).
# ---------------------------------------------------------------------------
relative_time() {
  local ts="$1"
  local ts_epoch
  ts_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" "+%s" 2>/dev/null)
  if [ -z "$ts_epoch" ]; then
    local clean_ts="${ts%%.*}Z"
    ts_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$clean_ts" "+%s" 2>/dev/null)
  fi
  [ -z "$ts_epoch" ] && echo "unknown" && return

  local now_epoch diff
  now_epoch=$(date "+%s")
  diff=$((now_epoch - ts_epoch))

  if [ $diff -lt 60 ]; then echo "just now"
  elif [ $diff -lt 3600 ]; then echo "$((diff / 60))min ago"
  elif [ $diff -lt 86400 ]; then echo "$((diff / 3600))h ago"
  else echo "$((diff / 86400))d ago"
  fi
}

# ---------------------------------------------------------------------------
# Clean stale sessions:
#   - Missing or null PID (malformed file)
#   - PID no longer running
#   - Heartbeat older than 30 minutes
#   - Zero-tool ghost sessions older than 5 minutes
# ---------------------------------------------------------------------------
now_epoch=$(date "+%s")
for f in "$SESSIONS_DIR"/*.json; do
  [ -f "$f" ] || continue
  pid=$(jq -r '.pid // empty' "$f" 2>/dev/null)
  heartbeat=$(jq -r '.heartbeat // empty' "$f" 2>/dev/null)
  tools_used=$(jq -r '.tools_used // 0' "$f" 2>/dev/null)

  if [ -z "$pid" ] || [ "$pid" = "null" ]; then
    rm -f "$f"
    continue
  fi

  if ! ps -p "$pid" > /dev/null 2>&1; then
    rm -f "$f"
    continue
  fi

  hb_epoch=""
  if [ -n "$heartbeat" ]; then
    hb_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$heartbeat" "+%s" 2>/dev/null)
    if [ -z "$hb_epoch" ]; then
      clean_ts="${heartbeat%%.*}Z"
      hb_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$clean_ts" "+%s" 2>/dev/null)
    fi
  fi

  if [ -n "$hb_epoch" ]; then
    age=$((now_epoch - hb_epoch))
    if [ $age -gt 1800 ]; then
      rm -f "$f"
      continue
    fi
    if [ "$tools_used" = "0" ] && [ $age -gt 300 ]; then
      rm -f "$f"
      continue
    fi
  fi
done

# ---------------------------------------------------------------------------
# Collect and display active sessions (excluding self)
# ---------------------------------------------------------------------------
count=0
session_lines=""
for f in "$SESSIONS_DIR"/*.json; do
  [ -f "$f" ] || continue
  sid=$(jq -r '.terminal_id // empty' "$f" 2>/dev/null)
  [ "$sid" = "$SESSION_ID" ] && continue

  count=$((count + 1))
  project=$(jq -r '.project // "unknown"' "$f" 2>/dev/null)
  task=$(jq -r '.task_summary // "working"' "$f" 2>/dev/null)
  heartbeat=$(jq -r '.heartbeat // empty' "$f" 2>/dev/null)
  rel=$(relative_time "$heartbeat")
  session_lines="${session_lines}  #${count}  ${project} (${sid}) -- ${rel} -- \"${task}\"\n"
done

# Check for an active hive (multi-agent coordination layer)
hive_line=""
if [ -f "$HIVE_CONFIG" ]; then
  hive_name=$(jq -r '.name // empty' "$HIVE_CONFIG" 2>/dev/null)
  if [ -n "$hive_name" ] && [ "$hive_name" != "null" ]; then
    hive_workers=$(jq -r '.workers | length // 0' "$HIVE_CONFIG" 2>/dev/null)
    hive_pending=$(jq -r '[.tasks[]? | select(.status == "pending")] | length' "$HIVE_CONFIG" 2>/dev/null)
    hive_line="\n  Hive: ${hive_name} (${hive_workers} workers, ${hive_pending} pending tasks)"
  fi
fi

if [ $count -gt 0 ] || [ -n "$hive_line" ]; then
  echo "=== Active Claude Sessions ==="
  if [ $count -gt 0 ]; then
    printf "$session_lines"
  else
    echo "  (no other sessions)"
  fi
  if [ -n "$hive_line" ]; then
    printf "$hive_line\n"
  fi
  echo "=============================="
fi

# ---------------------------------------------------------------------------
# Register this session
# ---------------------------------------------------------------------------
current_dir="${PWD}"
project=$(get_project_name "$current_dir")
now=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

cat > "$SESSIONS_DIR/${SESSION_ID}.json" <<ENDJSON
{
  "terminal_id": "$SESSION_ID",
  "pid": $CLAUDE_PID,
  "directory": "$current_dir",
  "project": "$project",
  "started": "$now",
  "heartbeat": "$now",
  "status": "active",
  "task_summary": "Starting session",
  "tools_used": 0,
  "event_cursor": 0
}
ENDJSON

# ---------------------------------------------------------------------------
# Cross-session event log: show recent activity from other sessions
# (last 2 hours). Helps avoid duplicate work across terminals.
# ---------------------------------------------------------------------------
EVENT_LOG="$HOME/.claude/shared-state/event-log.jsonl"

# Rotate event log if >500KB to keep startup fast
if [ -f "$EVENT_LOG" ]; then
  log_size=$(stat -f%z "$EVENT_LOG" 2>/dev/null || stat --printf="%s" "$EVENT_LOG" 2>/dev/null)
  if [ -n "$log_size" ] && [ "$log_size" -gt 524288 ]; then
    archive_date=$(date "+%Y-%m-%d")
    mv "$EVENT_LOG" "${EVENT_LOG%.jsonl}.${archive_date}.jsonl" 2>/dev/null
  fi
fi

if [ -f "$EVENT_LOG" ]; then
  two_hours_ago=$(date -u -v-2H "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
  if [ -n "$two_hours_ago" ]; then
    recent_events=$(jq -c --arg cutoff "$two_hours_ago" --arg self "$SESSION_ID" \
      'select(.ts >= $cutoff and .sid != $self)' "$EVENT_LOG" 2>/dev/null)
    if [ -n "$recent_events" ]; then
      event_count=$(echo "$recent_events" | wc -l | tr -d ' ')
      if [ "$event_count" -gt 0 ]; then
        echo "--- Recent Cross-Session Activity ---"
        echo "$recent_events" | jq -r '.type' 2>/dev/null | sort | uniq -c | sort -rn | head -8 | while read cnt etype; do
          echo "  ${etype} (${cnt})"
        done
        # Show last 5 events with detail
        echo "$recent_events" | tail -5 | jq -r '"\(.sid)/\(.project): \(.type) -- \(.payload | tostring | .[0:80])"' 2>/dev/null | while read line; do
          echo "  > $line"
        done
        echo "-------------------------------------"
      fi
    fi
  fi
fi
