---
name: deploy-verify
description: Post-deployment verification — probes health endpoints, checks key routes, verifies env vars, and scans logs for errors
allowed-tools: ["Bash", "Read"]
user_invocable: true
argument-hint: "[service-url] [--platform railway|vercel|fly]"
---

# Deploy Verify

Autonomous post-deployment verification. Probes health endpoints, checks key routes, confirms env vars are set, and scans recent logs for ERROR/FATAL patterns. Produces a pass/fail summary with specific failures listed.

## Step 1: Detect Target

Parse `$ARGUMENTS` for:
- `[service-url]` — the base URL to probe (e.g., `https://[your-project].railway.app`)
- `--platform [railway|vercel|fly]` — platform hint for log fetching

If no URL is provided, detect from platform config:

```bash
# Railway
railway status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('serviceUrl',''))"

# Vercel
cat .vercel/project.json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('projectId',''))"

# Fly
FLY_APP=$(grep "^app " fly.toml 2>/dev/null | awk '{print $3}' | tr -d '"')
echo "https://$FLY_APP.fly.dev"
```

## Step 2: Health Endpoint Probe

Run up to 3 probes with 10-second backoff. Require HTTP 200 AND a non-empty response body.

```bash
PROBE_URL="${SERVICE_URL}/health"
PROBE_PASS=0

for ATTEMPT in 1 2 3; do
  echo "--- Probe $ATTEMPT of 3 ---"
  HTTP_STATUS=$(curl -s -o /tmp/probe-body.json -w "%{http_code}" "$PROBE_URL" 2>/dev/null)
  BODY=$(cat /tmp/probe-body.json 2>/dev/null)
  
  echo "Status: $HTTP_STATUS"
  echo "Body: $BODY"
  
  if [ "$HTTP_STATUS" = "200" ] && [ -n "$BODY" ]; then
    PROBE_PASS=1
    break
  fi
  
  [ $ATTEMPT -lt 3 ] && sleep 10
done
```

If `/health` returns 404, fall back to probing `/api/health`, then `/`, then check the response `<title>` tag.

## Step 3: Critical Route Checks

Check 3-5 key routes that must return expected status codes. Adapt the list to your project:

```bash
declare -A ROUTES=(
  ["/"]="200"
  ["/api/health"]="200"
  ["/api/status"]="200"
  ["/nonexistent-route-xyz"]="404"
)

ROUTE_PASS=0
ROUTE_FAIL=0

for ROUTE in "${!ROUTES[@]}"; do
  EXPECTED="${ROUTES[$ROUTE]}"
  ACTUAL=$(curl -s -o /dev/null -w "%{http_code}" "${SERVICE_URL}${ROUTE}" 2>/dev/null)
  
  if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "PASS  $ROUTE → $ACTUAL"
    ((ROUTE_PASS++))
  else
    echo "FAIL  $ROUTE → $ACTUAL (expected $EXPECTED)"
    ((ROUTE_FAIL++))
  fi
done
```

## Step 4: Environment Verification

Confirm env vars are set without logging their values:

```bash
# Railway
railway variables 2>&1 | grep -E "^[A-Z_]+" | awk '{print $1}' | while read VAR; do
  echo "  $VAR: SET"
done

# Vercel
vercel env ls production 2>&1 | grep -v "^$\|^Vercel\|^>" | head -20

# Fly
fly secrets list --app "$FLY_APP" 2>&1 | awk '{print $1}' | tail -n +2 | while read VAR; do
  echo "  $VAR: SET"
done
```

Report which required vars from your project's env registry are present vs missing. Never log actual values.

## Step 5: Recent Log Scan

Scan the last 5 minutes of logs for ERROR or FATAL patterns:

```bash
# Railway
railway logs 2>&1 | tail -100 | grep -iE "error|fatal|exception|crash|unhandled" | head -20

# Fly
fly logs --app "$FLY_APP" 2>&1 | tail -100 | grep -iE "error|fatal|exception|crash|unhandled" | head -20

# Vercel (function logs)
vercel logs "${SERVICE_URL}" --limit 50 2>&1 | grep -iE "error|fatal|exception" | head -20
```

Classify findings:
- **CRITICAL**: Unhandled exception, crash loop, OOM, startup failure
- **WARNING**: Individual request errors, rate limits, timeout (not crash-level)
- **OK**: No errors in log window

## Output Format

```
DEPLOY VERIFY — [service-url]
Platform: [railway|vercel|fly]
Timestamp: [UTC]
──────────────────────────────────────

Step 1: Health Endpoint
  GET /health → [200 OK | FAIL]
  Response: [body excerpt]
  Result: [PASS | FAIL]

Step 2: Route Checks
  GET /          → 200  [PASS]
  GET /api/health → 200  [PASS]
  GET /api/status → 200  [PASS]
  GET /xyz        → 404  [PASS]
  Result: [N/M passed]

Step 3: Environment
  DATABASE_URL:   SET
  API_KEY:        SET
  MISSING_VAR:    NOT SET  ← blocker
  Result: [PASS | FAIL — N vars missing]

Step 4: Log Scan (last 5 min)
  Errors found: [N]
  [error excerpt if any]
  Result: [CLEAN | WARNING | CRITICAL]

──────────────────────────────────────
OVERALL: [PASS | FAIL]
Failures:
  - [specific failure 1]
  - [specific failure 2]
```

## Pass/Fail Criteria

**PASS** (all of the following):
- Health endpoint returns HTTP 200 with non-empty body
- All critical routes return expected status codes
- All required env vars are set
- No CRITICAL log patterns in the last 5 minutes

**FAIL** (any of the following):
- Health endpoint fails after 3 probes
- Any critical route returns unexpected status code
- Required env var missing
- CRITICAL log pattern (crash, unhandled exception, OOM)

**WARNING** (pass but note):
- WARNING-level log patterns present
- Some optional routes returning unexpected codes
- Log window is empty (may indicate logging config issue)
