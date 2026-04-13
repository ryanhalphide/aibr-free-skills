#!/usr/bin/env bash
# =============================================================================
# auto-diagnose.sh — PostToolUse Hook: Self-Healing Error Categorizer
# =============================================================================
# PURPOSE:
#   Intercepts every Bash tool failure, pattern-matches the error output
#   against 25+ known failure categories, and emits a structured fix
#   prescription. Claude reads this and applies the correct remedy instead
#   of blindly retrying or guessing.
#
#   Without this hook, Claude sees a raw error and has to reason from scratch
#   about what went wrong. This hook shortcircuits that reasoning by doing the
#   categorization automatically and providing a concrete next action.
#
# HOW TO WIRE (settings.json):
#   {
#     "hooks": {
#       "PostToolUse": [
#         {
#           "type": "command",
#           "command": "bash ~/.claude/hooks/post-tool/auto-diagnose.sh",
#           "matcher": "Bash"
#         }
#       ]
#     }
#   }
#
# BEHAVIOR:
#   - Exit 0 on success (no output, no overhead)
#   - On error: prints one-line category + fix prescription to stdout
#   - Never blocks — only informs. Claude decides what to do with the fix.
#
# THE 25+ FAILURE PATTERNS:
#   git_lock          — .git/index.lock exists from a dead git process
#   merge_conflict    — git merge/rebase hit a conflict
#   port_in_use       — EADDRINUSE, port already bound by another process
#   rate_limit        — 429 / quota exceeded from any API
#   auth              — 401 Unauthorized, token expired or missing
#   permission        — EACCES, file/dir not writable
#   missing_dep       — Cannot find module / ModuleNotFoundError
#   missing_file      — ENOENT, FileNotFoundError, path does not exist
#   build             — TypeScript error TS*, compilation failed, BUILD FAILED
#   runtime_type      — TypeError, ReferenceError at runtime
#   oom               — ENOMEM, heap out of memory
#   network           — ECONNREFUSED, ETIMEDOUT, fetch failed
#   crash             — SIGKILL, SIGBUS, segfault
#   python_traceback  — Traceback (most recent call last)
#   not_git           — fatal: not a git repository
#   npm               — npm ERR!, ERESOLVE dependency conflict
#   yarn              — yarn error
#   docker            — Docker daemon not running
#   docker_pull       — image pull failed / no matching manifest
#   (+ generic exit code detection for uncategorized errors)
#
# STDIN FORMAT:
#   { "tool_input": { "command": "..." }, "tool_output": "...", "exit_code": 1 }
# =============================================================================

INPUT=$(cat)

# Fast path: exit code 0 means success — stay completely silent
echo "$INPUT" | grep -q '"exit_code"[[:space:]]*:[[:space:]]*0' && exit 0

# Extract tool output (up to 3000 chars to keep analysis fast)
OUTPUT=$(echo "$INPUT" | grep -o '"tool_output"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"tool_output"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' | head -c 3000)

# Fallback: check stderr field if tool_output is empty
if [[ -z "$OUTPUT" ]]; then
    OUTPUT=$(echo "$INPUT" | grep -o '"stderr"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"stderr"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//' | head -c 3000)
fi

# Nothing to diagnose
[[ -z "$OUTPUT" ]] && exit 0

# ---------------------------------------------------------------------------
# Detect whether this is actually an error (avoid false positives from
# commands that mention error-adjacent words in normal output)
# ---------------------------------------------------------------------------
HAS_ERROR=0

# Explicit exit code in output text
echo "$OUTPUT" | grep -qiE "^Exit code [1-9]|exit code: [1-9]|exited with code [1-9]" && HAS_ERROR=1

# Error prefixes and language runtime exceptions
echo "$OUTPUT" | grep -qiE "^error[ :\[]|^fatal:|^FATAL|panic:|Traceback \(most recent|SyntaxError:|TypeError:|ReferenceError:" && HAS_ERROR=1

# Build and compile failures
echo "$OUTPUT" | grep -qiE "error TS[0-9]|Cannot find module|ENOENT|BUILD FAILED|compilation failed" && HAS_ERROR=1

# Runtime and resource failures
echo "$OUTPUT" | grep -qiE "EADDRINUSE|EACCES|ENOMEM|heap out of memory|SIGKILL|SIGBUS|segfault" && HAS_ERROR=1

# Git failures
echo "$OUTPUT" | grep -qiE "index\.lock.*exists|unable to create|CONFLICT|merge conflict|fatal: not a git" && HAS_ERROR=1

# Network and API failures
echo "$OUTPUT" | grep -qiE "ECONNREFUSED|ETIMEDOUT|429 Too Many|401 Unauthorized|403 Forbidden|fetch failed|certificate" && HAS_ERROR=1

# Python module errors
echo "$OUTPUT" | grep -qiE "ModuleNotFoundError|ImportError|FileNotFoundError|PermissionError" && HAS_ERROR=1

# Package manager errors
echo "$OUTPUT" | grep -qiE "npm ERR!|npm warn|ERR_PNPM|yarn error|ERESOLVE" && HAS_ERROR=1

# Docker errors
echo "$OUTPUT" | grep -qiE "docker: Error|Cannot connect to the Docker daemon|no matching manifest|pull access denied" && HAS_ERROR=1

# No error signals detected — stay completely silent
[[ $HAS_ERROR -eq 0 ]] && exit 0

# ---------------------------------------------------------------------------
# Categorize the error (most specific patterns first)
# ---------------------------------------------------------------------------
CATEGORY="unknown"
FIX=""

if echo "$OUTPUT" | grep -qiE "index\.lock.*exists|unable to create.*index\.lock"; then
    CATEGORY="git_lock"
    FIX="Remove stale lock: rm <repo>/.git/index.lock (verify no active git process first with: pgrep -f git)"

elif echo "$OUTPUT" | grep -qiE "CONFLICT|merge conflict"; then
    CATEGORY="merge_conflict"
    FIX="Run git diff to see conflicts. Resolve each conflicted file manually, git add, then continue the operation."

elif echo "$OUTPUT" | grep -qiE "EADDRINUSE|address already in use"; then
    PORT=$(echo "$OUTPUT" | grep -oE "([: ]|port )[0-9]{2,5}" | grep -oE "[0-9]+" | head -1)
    CATEGORY="port_in_use"
    FIX="Kill process on port ${PORT:-?}: lsof -ti:${PORT:-PORT} | xargs kill -9, then retry."

elif echo "$OUTPUT" | grep -qiE "429|rate limit|quota exceeded|too many requests"; then
    CATEGORY="rate_limit"
    FIX="Rate limited. Wait 30s or switch to a lighter model. Do NOT retry the same request immediately."

elif echo "$OUTPUT" | grep -qiE "401|Unauthorized|authentication failed|auth.*fail|invalid.*token|token.*invalid"; then
    CATEGORY="auth"
    FIX="Auth failure. Check that the token/credentials are set and not expired. Verify relevant env vars."

elif echo "$OUTPUT" | grep -qiE "EACCES|Permission denied"; then
    CATEGORY="permission"
    FIX="Permission denied. Check file ownership with ls -la. Tell the user the exact chmod/chown command needed — do NOT use sudo autonomously."

elif echo "$OUTPUT" | grep -qiE "Cannot find module|MODULE_NOT_FOUND|ModuleNotFoundError|ImportError"; then
    CATEGORY="missing_dep"
    FIX="Missing dependency. Run the appropriate install (npm install / pip install -r requirements.txt) then retry."

elif echo "$OUTPUT" | grep -qiE "ENOENT|No such file or directory|FileNotFoundError"; then
    CATEGORY="missing_file"
    FIX="File/directory not found. Verify the path exists before retrying. Check for typos or wrong working directory."

elif echo "$OUTPUT" | grep -qiE "error TS[0-9]|compilation failed|BUILD FAILED|tsc.*error"; then
    CATEGORY="build_ts"
    FIX="TypeScript/build error. Read the specific error line and file path. Fix the type error, then rebuild."

elif echo "$OUTPUT" | grep -qiE "SyntaxError|compilation failed"; then
    CATEGORY="build_syntax"
    FIX="Syntax error in source code. Read the error line number, fix the syntax, then retry."

elif echo "$OUTPUT" | grep -qiE "TypeError|ReferenceError"; then
    CATEGORY="runtime_type"
    FIX="Runtime type error. Check for null/undefined values, incorrect function signatures, or wrong variable types."

elif echo "$OUTPUT" | grep -qiE "ENOMEM|heap out of memory|JavaScript heap out of memory"; then
    CATEGORY="oom"
    FIX="Out of memory. Options: reduce batch size, add NODE_OPTIONS='--max-old-space-size=4096', or kill other memory-heavy processes."

elif echo "$OUTPUT" | grep -qiE "ECONNREFUSED|ETIMEDOUT|fetch failed|connection refused"; then
    CATEGORY="network"
    FIX="Network error. Check if the target service is running and reachable. Verify URL, port, and that no firewall is blocking."

elif echo "$OUTPUT" | grep -qiE "certificate|SSL|TLS|CERT_"; then
    CATEGORY="tls"
    FIX="TLS/certificate error. Check cert expiry, verify the hostname matches the cert, or set NODE_TLS_REJECT_UNAUTHORIZED for dev only."

elif echo "$OUTPUT" | grep -qiE "SIGKILL|SIGBUS|segfault|Segmentation fault"; then
    CATEGORY="crash"
    FIX="Process crashed. Check for corrupt binaries, disk space exhaustion, or extreme memory pressure. Try again in isolation."

elif echo "$OUTPUT" | grep -qiE "Traceback \(most recent call last\)"; then
    CATEGORY="python_traceback"
    FIX="Python exception. Read the LAST line of the traceback for the actual error type and message."

elif echo "$OUTPUT" | grep -qiE "fatal: not a git repo|not a git repository"; then
    CATEGORY="not_git"
    FIX="Not a git repository. Verify you are in the correct directory with: pwd. Run git init if this is a new project."

elif echo "$OUTPUT" | grep -qiE "npm ERR!|ERESOLVE|peer dep"; then
    CATEGORY="npm"
    FIX="npm install error. Try: rm -rf node_modules package-lock.json && npm install. If ERESOLVE, add --legacy-peer-deps."

elif echo "$OUTPUT" | grep -qiE "yarn error|yarn.*failed"; then
    CATEGORY="yarn"
    FIX="yarn error. Try: yarn install --force. Check yarn.lock for conflicts."

elif echo "$OUTPUT" | grep -qiE "docker: Error|Cannot connect to the Docker daemon|Is the docker daemon running"; then
    CATEGORY="docker_daemon"
    FIX="Docker daemon not running. Start Docker Desktop (macOS: open -a Docker) and wait 10s for it to initialize."

elif echo "$OUTPUT" | grep -qiE "no matching manifest|pull access denied|manifest.*not found"; then
    CATEGORY="docker_pull"
    FIX="Docker image pull failed. Check image name and tag spelling. For private registries, run: docker login <registry>"

elif echo "$OUTPUT" | grep -qiE "403 Forbidden|Access denied|not authorized"; then
    CATEGORY="forbidden"
    FIX="403 Forbidden. The credentials are valid but lack permission. Check IAM roles, API scopes, or request the required permission."
fi

# ---------------------------------------------------------------------------
# Emit the diagnostic — this is what Claude receives as post-tool context
# ---------------------------------------------------------------------------
cat <<EOF
[AUTO-DIAGNOSE] error=${CATEGORY}
Fix: ${FIX}
Protocol: (1) Do NOT retry the same command. (2) Apply the fix above. (3) Verify the fix worked. (4) Resume your original task.
EOF
