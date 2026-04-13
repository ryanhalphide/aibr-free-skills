---
name: system-health
description: Run a full health check across all deployed services, memory vault, hooks, and MCP servers. Use for morning briefings and incident triage.
allowed-tools: ["Bash", "Read", "Glob", "Grep"]
user_invocable: true
triggers: ["health check", "system status", "everything ok", "check all services", "morning check", "is everything up"]
---

# System Health Check

Full status sweep for your deployed services and local tooling. Run at session start, after incidents, or any time service behavior is unexpected.

Adapt the service list, URLs, and project paths to match your setup before using.

## Quick Health (30 seconds)

Check the most critical things first:

```bash
# Check primary backend service (Railway example)
cd ~/Code/your-project && railway status 2>/dev/null | tail -5

# Check if local dev server is running
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health 2>/dev/null || echo "local: not running"

# Check vault last-sync if you have one
ls -la ~/.claude/memory/.last-vault-sync 2>/dev/null || echo "Vault sync: never run"

# Check hook health
cat ~/.claude/health-check.log 2>/dev/null | tail -5
```

## Full Health Check

### 1. Deployed Services

Define your services in this table and run the corresponding check command for each:

| Service | Platform | Check Command | Expected Response |
|---|---|---|---|
| Backend API | Railway | `railway status` | `STATUS: ACTIVE` |
| Frontend | Vercel | `vercel ls --prod` | Latest deployment ready |
| Worker | Fly.io | `fly status --app [your-app]` | Running |
| Automation | [your-n8n-instance] | `curl [your-n8n-instance]` | 200 OK |

For each service, run the check and record the result as `OK` or `FAIL`.

```bash
# Generic health probe pattern — adapt URL and expected response
check_service() {
  local name=$1
  local url=$2
  local expected=$3
  
  STATUS=$(curl -s -o /tmp/health-${name}.json -w "%{http_code}" "$url" 2>/dev/null)
  
  if [ "$STATUS" = "$expected" ]; then
    echo "$name: OK ($STATUS)"
  else
    echo "$name: FAIL (got $STATUS, expected $expected)"
  fi
}

check_service "backend" "https://[your-railway-project].railway.app/health" "200"
check_service "frontend" "https://[your-vercel-project].vercel.app/api/health" "200"
check_service "automation" "https://[your-n8n-instance]/healthz" "200"
```

### 2. MCP Server Status

```bash
# Check settings.json for active MCPs
cat ~/.claude/settings.json | python3 -c "
import json, sys
s = json.load(sys.stdin)
servers = s.get('mcpServers', {})
print(f'MCP servers: {len(servers)} configured')
for name in servers:
    print(f'  - {name}')
"
```

### 3. Hook Health

```bash
# List active hooks
cat ~/.claude/settings.json | python3 -c "
import json, sys
s = json.load(sys.stdin)
hooks = s.get('hooks', {})
for event, entries in hooks.items():
    print(f'{event}: {len(entries)} hook(s)')
"

# Check for disabled hooks (may need attention)
ls ~/.claude/hooks/*.disabled 2>/dev/null || echo "No disabled hooks"
```

### 4. Local Environment

```bash
# Check critical tools
for tool in node python3 git docker; do
  command -v $tool >/dev/null 2>&1 && echo "$tool: OK" || echo "$tool: MISSING"
done

# Check disk space (warn if >80%)
df -h / | awk 'NR==2{print "Disk: " $5 " used (" $4 " free)"}'
```

## Triage Matrix

When something looks wrong, use this as a starting guide:

| Symptom | First Check | Likely Cause |
|---|---|---|
| Service returning 502 | Platform logs | Startup crash or OOM |
| Frontend blank screen | Browser console | Build error or missing env var |
| Automation workflow failed | [your-n8n-instance] logs | Credential expired or webhook error |
| MCP tool errors | settings.json | Auth token expired |
| High latency | Platform metrics | Cold start, underpowered instance |
| Database errors | Service logs | Connection limit, migration failure |

## Output Format

Report results as a status table:

```
SYSTEM HEALTH — [date]
──────────────────────────────────────
Backend API     [OK/FAIL]  [version or error]
Frontend        [OK/FAIL]  [deployed N ago or error]
Automation      [OK/FAIL]  [status]
MCP servers     [N configured]
Hooks           [N active]
Disk            [X% used]
──────────────────────────────────────
OVERALL: [ALL OK | N FAILING]
```

Any failures shown with specific triage suggestion based on the triage matrix above.

## Customization

To adapt this skill to your project:

1. Replace `[your-railway-project]`, `[your-vercel-project]`, `[your-n8n-instance]` with your actual service URLs
2. Add or remove rows from the service table to match what you deploy
3. Update the triage matrix with project-specific failure modes you've encountered
4. Set the `WIKI_ROOT` path if you have a knowledge vault to check
5. Update the hook health check to match your `.claude/hooks/` setup
