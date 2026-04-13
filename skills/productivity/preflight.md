---
name: preflight
description: Pre-session health check — verifies MCP servers, git status, environment variables, and context budget before starting work
allowed-tools: ["Bash", "Read", "Glob"]
user_invocable: true
---

# Pre-Flight Checklist

A quick 4-check pre-session ritual that catches broken tools, missing auth, and wrong context before you waste time mid-task.

## Check 1: MCP Servers

List what's connected and flag anything that's down:

```bash
cat ~/.claude/settings.json | python3 -c "
import json, sys
s = json.load(sys.stdin)
servers = s.get('mcpServers', {})
print(f'MCP servers configured: {len(servers)}')
for name in servers:
    print(f'  - {name}')
"
```

Any MCP server your planned work depends on that isn't listed here is a blocker. Surface it now.

## Check 2: Git State

```bash
# Current branch
git branch --show-current

# Uncommitted changes
git status --short

# Sync status with remote
git fetch --dry-run 2>&1 | head -5
```

Flag if:
- You're on `main` and the work isn't a hotfix (should be on a feature branch)
- There are uncommitted changes that could conflict with incoming work
- The branch is behind remote by more than 10 commits

## Check 3: Environment

Key env vars present (never log values, only confirm presence):

```bash
# Check .env files exist
ls .env .env.local .env.production 2>/dev/null || echo "No .env files found"

# Check critical tools
for tool in node python3 docker git; do
  command -v $tool >/dev/null 2>&1 && echo "$tool: OK" || echo "$tool: MISSING"
done

# Check node_modules
[ -d "node_modules" ] && echo "node_modules: installed" || echo "node_modules: MISSING — run npm install"
```

## Check 4: Context Budget

If a plan file exists, read it and report current progress:

```bash
# Check for active plan files
ls ~/saved-plan.md 2>/dev/null || ls .claude/saved-plan.md 2>/dev/null || echo "No active plan file"
```

If a plan file exists, read it and summarize:
- Total tasks
- Tasks completed (done/verified)
- Tasks remaining
- Current blocker if any

## Output Format

```
PRE-FLIGHT — [date]
─────────────────────────────────
MCP servers    [N configured] / [check result]
Git state      [branch] / [clean|N changes] / [sync status]
Environment    [OK | MISSING: list]
Context budget [plan: N tasks, M done | no active plan]
─────────────────────────────────
STATUS: GO
```

or

```
STATUS: HOLD
Blockers:
- [specific issue 1]
- [specific issue 2]
```

Only output GO when all 4 checks pass. List every blocker explicitly in HOLD state — never proceed past a blocker hoping it won't matter.
