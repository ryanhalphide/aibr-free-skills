#!/usr/bin/env bash
# =============================================================================
# janitor.sh — SessionStart Hook: TTL-Based Cleanup
# =============================================================================
# PURPOSE:
#   Runs at most once per day (guarded by a sentinel file). Prunes old temp
#   files, rotates large JSONL logs, and keeps the ~/.claude directory lean.
#   Prevents unbounded growth of session artifacts, debug dumps, paste caches,
#   and subagent plan shards.
#
# HOW TO WIRE (settings.json):
#   {
#     "hooks": {
#       "SessionStart": [
#         { "type": "command", "command": "bash ~/.claude/hooks/session-start/janitor.sh" }
#       ]
#     }
#   }
#
# SAFE TO RUN ANYTIME:
#   The one-per-day sentinel means it exits immediately on all subsequent
#   sessions in the same calendar day. Use --dry-run to preview deletions
#   without making any changes.
#
# TTLs (configurable below):
#   projects/*.jsonl              60 days
#   file-history/                 keep newest 50
#   shell-snapshots/              14 days
#   session-env/                  14 days
#   debug/                        7 days
#   paste-cache/                  7 days
#   plans/*-agent-a*.md           14 days (subagent plan shards)
#   shared-state/plan-approved-*  3 days
#   backups/                      keep newest 10
#   event-log.jsonl               rotate when >5MB
#   task-log.jsonl                rotate when >5MB
#   subagent-results.jsonl        rotate when >5MB
#
# CUSTOMIZATION:
#   Add prune_older_than / prune_keep_newest / rotate_jsonl calls at the
#   bottom of this file for your own directories.
# =============================================================================

set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
SHARED="${CLAUDE_DIR}/shared-state"
SENTINEL="${SHARED}/.janitor-last-run"
DRY_RUN=false
DELETED=0
ROTATED=0

for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

# Guard: run at most once per calendar day
TODAY=$(date +%Y-%m-%d)
if [[ -f "$SENTINEL" ]]; then
  LAST=$(cat "$SENTINEL" 2>/dev/null || echo "")
  if [[ "$LAST" == "$TODAY" ]]; then
    exit 0
  fi
fi

if $DRY_RUN; then echo "[janitor] --dry-run mode: no changes will be made"; fi

# ---------------------------------------------------------------------------
# prune_older_than DIR DAYS [PATTERN]
#   Deletes files/dirs in DIR older than DAYS days, optionally filtered by
#   shell glob PATTERN.
# ---------------------------------------------------------------------------
prune_older_than() {
  local dir="$1" days="$2" pattern="${3:-*}"
  [[ -d "$dir" ]] || return 0
  while IFS= read -r -d '' f; do
    if $DRY_RUN; then
      echo "[janitor] would delete: $f"
    else
      rm -rf "$f"
      ((DELETED++)) || true
    fi
  done < <(find "$dir" -maxdepth 1 -name "$pattern" -mtime "+${days}" -print0 2>/dev/null)
}

# ---------------------------------------------------------------------------
# prune_keep_newest DIR KEEP
#   Keeps only the KEEP newest entries in DIR; deletes the rest.
# ---------------------------------------------------------------------------
prune_keep_newest() {
  local dir="$1" keep="$2"
  [[ -d "$dir" ]] || return 0
  local count
  count=$(find "$dir" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$count" -gt "$keep" ]]; then
    find "$dir" -maxdepth 1 -mindepth 1 -exec stat -f '%m %N' {} \; 2>/dev/null \
      | sort -n | head -n "$(( count - keep ))" | cut -d' ' -f2- \
      | while IFS= read -r f; do
        if $DRY_RUN; then
          echo "[janitor] would delete (excess): $f"
        else
          rm -rf "$f"
          ((DELETED++)) || true
        fi
      done
  fi
}

# ---------------------------------------------------------------------------
# rotate_jsonl FILE
#   Compresses FILE to archive/ if it exceeds 5MB, then truncates it.
# ---------------------------------------------------------------------------
rotate_jsonl() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local size
  size=$(wc -c < "$file" | tr -d ' ')
  if (( size > 5242880 )); then
    local archive_dir="${SHARED}/archive"
    mkdir -p "$archive_dir"
    local dest
    dest="${archive_dir}/$(date +%Y-%m)-$(basename "$file").gz"
    if $DRY_RUN; then
      echo "[janitor] would rotate: $file -> $dest (${size} bytes)"
    else
      gzip -c "$file" > "$dest"
      : > "$file"
      ((ROTATED++)) || true
    fi
  fi
}

# ---------------------------------------------------------------------------
# Run all cleanup tasks
# ---------------------------------------------------------------------------
prune_older_than "${CLAUDE_DIR}/projects" 60 "*.jsonl"
prune_older_than "${CLAUDE_DIR}/shell-snapshots" 14
prune_older_than "${CLAUDE_DIR}/session-env" 14
prune_older_than "${CLAUDE_DIR}/debug" 7
prune_older_than "${CLAUDE_DIR}/paste-cache" 7
prune_older_than "${CLAUDE_DIR}/plans" 14 "*-agent-a*.md"
prune_older_than "${SHARED}" 3 "plan-approved-*"
prune_keep_newest "${CLAUDE_DIR}/file-history" 50
prune_keep_newest "${CLAUDE_DIR}/backups" 10
rotate_jsonl "${SHARED}/event-log.jsonl"
rotate_jsonl "${SHARED}/task-log.jsonl"
rotate_jsonl "${SHARED}/subagent-results.jsonl"

# Record sentinel and summary
if ! $DRY_RUN; then
  echo "$TODAY" > "$SENTINEL"
  echo "[janitor] complete: deleted=${DELETED} files, rotated=${ROTATED} logs"
fi
