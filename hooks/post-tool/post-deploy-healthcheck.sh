#!/usr/bin/env bash
# =============================================================================
# post-deploy-healthcheck.sh — PostToolUse Hook
# =============================================================================
# PURPOSE:
#   Automatically verifies deployments immediately after any deploy command
#   runs. Extracts the deployment URL from the command or environment, curls
#   the /health endpoint, and reports pass/fail. This catches silent deploy
#   failures that the deploy CLI reports as "success" but that leave the
#   service unhealthy.
#
#   Without this hook, Claude declares a deployment done based on the CLI
#   exit code alone. But many platforms emit exit 0 even when the deployed
#   container crashes on startup.
#
# HOW TO WIRE (settings.json):
#   {
#     "hooks": {
#       "PostToolUse": [
#         {
#           "type": "command",
#           "command": "bash ~/.claude/hooks/post-tool/post-deploy-healthcheck.sh",
#           "matcher": "Bash"
#         }
#       ]
#     }
#   }
#
# SUPPORTED PLATFORMS (auto-detected from command):
#   - Fly.io (flyctl deploy) — reads app name from -a flag or fly.toml
#   - Railway (railway up / railway deploy) — reads RAILWAY_PUBLIC_DOMAIN env var
#   - Vercel (vercel deploy / vercel --prod) — reads deployment URL from output
#   - Generic: set DEPLOY_HEALTH_URL env var to override detection
#
# RETRY BEHAVIOR:
#   Retries the health check 3 times with 5-second delays between attempts.
#   This handles slow-start containers that need a few seconds to bind.
#
# CUSTOMIZATION:
#   1. Add your platform's URL detection pattern below
#   2. Change HEALTH_PATH from /health to your app's health endpoint
#   3. Adjust retry count and sleep duration for your startup time
#   4. Set DEPLOY_HEALTH_URL in your shell to override all detection
#
# STDIN FORMAT:
#   { "tool_input": { "command": "flyctl deploy -a my-app" }, "tool_output": "..." }
# =============================================================================

INPUT=$(cat)
HEALTH_PATH="${HEALTH_PATH:-/health}"
url=""

# Extract the command that was run
cmd=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

# Early exit: not a deploy command
if ! echo "$cmd" | grep -qiE "flyctl deploy|railway up|railway deploy|vercel.*--prod|vercel deploy"; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Manual override: DEPLOY_HEALTH_URL takes priority over all detection
# ---------------------------------------------------------------------------
if [ -n "${DEPLOY_HEALTH_URL:-}" ]; then
  url="$DEPLOY_HEALTH_URL"
fi

# ---------------------------------------------------------------------------
# Fly.io detection
# Reads -a / --app flag, or falls back to fly.toml in current dir
# ---------------------------------------------------------------------------
if [ -z "$url" ] && echo "$cmd" | grep -q "flyctl"; then
  app=$(echo "$cmd" | grep -oE '(-a|--app)[[:space:]]+[a-zA-Z0-9_-]+' | awk '{print $2}')
  if [ -z "$app" ]; then
    app=$(cat fly.toml 2>/dev/null | grep '^app' | head -1 | grep -oE '"[^"]*"' | tr -d '"')
  fi
  if [ -n "$app" ]; then
    url="https://${app}.fly.dev${HEALTH_PATH}"
  fi
fi

# ---------------------------------------------------------------------------
# Railway detection
# Uses RAILWAY_PUBLIC_DOMAIN environment variable set by Railway's CLI
# ---------------------------------------------------------------------------
if [ -z "$url" ] && echo "$cmd" | grep -qiE "railway (up|deploy)"; then
  if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    url="https://${RAILWAY_PUBLIC_DOMAIN}${HEALTH_PATH}"
  fi
fi

# ---------------------------------------------------------------------------
# Vercel detection
# Extracts the deployment URL from the CLI output (contains .vercel.app)
# ---------------------------------------------------------------------------
if [ -z "$url" ] && echo "$cmd" | grep -qiE "vercel"; then
  output_text=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_output', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")
  vercel_url=$(echo "$output_text" | grep -oE 'https://[a-zA-Z0-9_-]+\.vercel\.app' | head -1)
  if [ -n "$vercel_url" ]; then
    url="${vercel_url}${HEALTH_PATH}"
  fi
fi

# No URL detected — exit silently
if [ -z "$url" ]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Health check with retries
# ---------------------------------------------------------------------------
echo "Verifying deployment at $url..."
RETRY_COUNT=3
RETRY_DELAY=5
STATUS=""

for i in $(seq 1 $RETRY_COUNT); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")

  if [ "$STATUS" = "200" ]; then
    echo "Health check PASSED ($url -> 200 OK)"
    exit 0
  fi

  if [ "$i" -lt "$RETRY_COUNT" ]; then
    echo "Health check attempt $i/$RETRY_COUNT: $STATUS — retrying in ${RETRY_DELAY}s..."
    sleep "$RETRY_DELAY"
  fi
done

echo "HEALTH CHECK FAILED ($url -> $STATUS) — deployment may be unhealthy. Verify manually."
exit 0  # Non-blocking: warn but don't block Claude from continuing
