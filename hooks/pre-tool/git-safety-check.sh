#!/bin/bash
# =============================================================================
# git-safety-check.sh — PreToolUse Hook
# =============================================================================
# PURPOSE:
#   Pre-flight safety checks before any git commit, push, or add operation.
#   Catches common problems before they become expensive to fix:
#     1. Stale or too-old git binary (needs 2.30+)
#     2. Git repo initialized in the home directory (catastrophic)
#     3. Large files (>5MB) accidentally staged
#     4. Missing .gitignore patterns for common large-file types
#     5. Large untracked files that should probably be ignored
#
# HOW TO WIRE (settings.json):
#   {
#     "hooks": {
#       "PreToolUse": [
#         {
#           "type": "command",
#           "command": "bash ~/.claude/hooks/pre-tool/git-safety-check.sh",
#           "matcher": "Bash"
#         }
#       ]
#     }
#   }
#
# BLOCKING BEHAVIOR:
#   - Errors (ERRORS array non-empty): exits with code 1, which Claude Code
#     treats as a blocking failure. Claude will see the error output and
#     must fix the problem before retrying.
#   - Warnings only: exits with code 0 (non-blocking), prints advisory text.
#   - Not a git command: exits 0 immediately (fast path).
#
# STDIN FORMAT:
#   Claude Code passes the tool invocation as JSON on stdin:
#   { "tool_name": "Bash", "tool_input": { "command": "git commit -m '...'" } }
# =============================================================================

set -euo pipefail

# Read tool input from stdin
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | grep -oE '"command"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"command"\s*:\s*"//;s/"$//' || echo "")

# Fast path: only run for git commit/push/add commands
if ! echo "$COMMAND" | grep -qE '^\s*git (commit|push|add)\b'; then
  exit 0
fi

ERRORS=()
WARNINGS=()

# ---------------------------------------------------------------------------
# Check 1: Git binary version (minimum 2.30+)
# Older git versions lack --pathspec-from-file and have known security issues.
# ---------------------------------------------------------------------------
GIT_BIN=$(which git 2>/dev/null || echo "")
if [ -z "$GIT_BIN" ]; then
  ERRORS+=("CRITICAL: No git binary found in PATH")
else
  GIT_VERSION=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  GIT_MAJOR=$(echo "$GIT_VERSION" | cut -d. -f1)
  GIT_MINOR=$(echo "$GIT_VERSION" | cut -d. -f2)

  if [ "$GIT_MAJOR" -lt 2 ] || ([ "$GIT_MAJOR" -eq 2 ] && [ "$GIT_MINOR" -lt 30 ]); then
    ERRORS+=("STALE GIT: $GIT_BIN is v${GIT_VERSION} (need 2.30+). System git at /usr/bin/git may be newer.")
    if [ -x /usr/bin/git ]; then
      SYS_VERSION=$(/usr/bin/git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
      ERRORS+=("FIX: Use /usr/bin/git (v${SYS_VERSION}) or update: brew install git / brew upgrade git")
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Check 2: Repo root must not be the home directory
# A git repo at ~ tracks everything in home — a catastrophic misconfiguration.
# ---------------------------------------------------------------------------
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$REPO_ROOT" ]; then
  HOME_DIR=$(eval echo ~)
  if [ "$REPO_ROOT" = "$HOME_DIR" ]; then
    ERRORS+=("REPO ROOT IS HOME DIR: $REPO_ROOT -- git was initialized in home directory. Remove ~/.git or use correct project directory.")
  fi
fi

# ---------------------------------------------------------------------------
# Check 3: Large staged files (>5MB)
# These will bloat the repo history permanently.
# ---------------------------------------------------------------------------
LARGE_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | while read -r f; do
  if [ -f "$f" ]; then
    SIZE=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
    if [ "$SIZE" -gt 5242880 ]; then
      echo "$f ($(( SIZE / 1048576 ))MB)"
    fi
  fi
done)

if [ -n "$LARGE_FILES" ]; then
  ERRORS+=("LARGE FILES STAGED: $LARGE_FILES -- Add to .gitignore or use Git LFS")
fi

# ---------------------------------------------------------------------------
# Check 4: Common large-file patterns missing from .gitignore
# ---------------------------------------------------------------------------
if [ -f .gitignore ]; then
  MISSING_PATTERNS=()
  for pattern in "*.mp4" "*.mov" "*.avi" "*.mkv" "node_modules"; do
    if ! grep -q "$pattern" .gitignore 2>/dev/null; then
      MISSING_PATTERNS+=("$pattern")
    fi
  done
  if [ ${#MISSING_PATTERNS[@]} -gt 0 ]; then
    WARNINGS+=("GITIGNORE GAPS: Missing patterns: ${MISSING_PATTERNS[*]}")
  fi
fi

# ---------------------------------------------------------------------------
# Check 5: Large untracked files (>10MB) that should be gitignored
# Non-blocking advisory only.
# ---------------------------------------------------------------------------
LARGE_UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | while read -r f; do
  if [ -f "$f" ]; then
    SIZE=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
    if [ "$SIZE" -gt 10485760 ]; then
      echo "$f ($(( SIZE / 1048576 ))MB)"
    fi
  fi
done | head -5)

if [ -n "$LARGE_UNTRACKED" ]; then
  WARNINGS+=("LARGE UNTRACKED FILES: $LARGE_UNTRACKED -- Consider adding to .gitignore")
fi

# ---------------------------------------------------------------------------
# Output results
# ---------------------------------------------------------------------------
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "GIT SAFETY CHECK FAILED:"
  for err in "${ERRORS[@]}"; do
    echo "  ERROR: $err"
  done
  if [ ${#WARNINGS[@]} -gt 0 ]; then
    for warn in "${WARNINGS[@]}"; do
      echo "  WARNING: $warn"
    done
  fi
  exit 1  # Blocking: Claude Code will not proceed
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "GIT SAFETY WARNINGS:"
  for warn in "${WARNINGS[@]}"; do
    echo "  WARNING: $warn"
  done
fi

echo "GIT SAFETY: OK"
exit 0
