# Claude Code Hooks

Claude Code hooks let you inject shell scripts into every event in the AI's runtime. They transform Claude Code from a reactive request-response system into a **proactive, self-correcting runtime** with persistent safety gates, automated quality checks, and compound memory.

## What Are Hooks?

Hooks are shell scripts (or any executable) that Claude Code runs at specific lifecycle events. They receive the tool input/output as JSON on stdin. They can:

- **Print to stdout** — Claude reads this output and it's added to context
- **Exit with code 0** — success / allow
- **Exit with code 2** — block the action (for PreToolUse hooks)
- **Print JSON with `{"decision": "block", "reason": "..."}**` — structured block

Hooks add zero cognitive overhead to Claude itself. They run in the background and only surface when something is wrong.

---

## The Full Event Lifecycle

| Event | When It Fires | Typical Use |
|-------|--------------|-------------|
| `SessionStart` | Once, when the Claude session initializes | Inject git state, coordinate multi-session, cleanup |
| `PreToolUse` | Before every tool call | Safety gates, trust checks, blocking dangerous ops |
| `PostToolUse` | After every tool call completes | Error categorization, quality checks, deploy verification |
| `Stop` | When the session ends | Memory extraction, completeness checks, session capture |
| `PreCompact` | Before context compaction | Save state, emit checkpoints |
| `UserPromptSubmit` | When the user submits a message | Route to workflows, analyze intent |
| `TaskCreated` | When a task is created | Lifecycle logging |
| `TaskCompleted` | When a task is marked complete | Verification gates, metrics |
| `SubagentStop` | When a sub-agent finishes | Collect results, aggregate outputs |
| `ConfigChange` | When settings.json changes | Backup configuration, audit trail |

---

## How to Wire a Hook (settings.json)

Hooks live in your `~/.claude/settings.json`. The full structure:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "bash ~/.claude/hooks/session-start/session-awareness.sh"
      },
      {
        "type": "command",
        "command": "bash ~/.claude/hooks/session-start/janitor.sh"
      },
      {
        "type": "command",
        "command": "bash ~/.claude/hooks/session-start/inject-git-state.sh"
      }
    ],
    "PreToolUse": [
      {
        "type": "command",
        "command": "bash ~/.claude/hooks/pre-tool/git-safety-check.sh",
        "matcher": "Bash"
      },
      {
        "type": "command",
        "command": "bash ~/.claude/hooks/pre-tool/trust-gate.sh"
      },
      {
        "type": "command",
        "command": "bash ~/.claude/hooks/pre-tool/env-blocker.sh",
        "matcher": "Write|Edit"
      }
    ],
    "PostToolUse": [
      {
        "type": "command",
        "command": "bash ~/.claude/hooks/post-tool/auto-diagnose.sh",
        "matcher": "Bash"
      },
      {
        "type": "command",
        "command": "bash ~/.claude/hooks/post-tool/context-budget-warn.sh"
      },
      {
        "type": "command",
        "command": "bash ~/.claude/hooks/post-tool/post-deploy-healthcheck.sh",
        "matcher": "Bash"
      }
    ],
    "Stop": [
      {
        "type": "command",
        "command": "bash ~/.claude/hooks/stop/memory-extract.sh"
      }
    ]
  }
}
```

### The `matcher` field

`matcher` is a regex applied to the tool name. If it doesn't match, the hook is skipped entirely. Use it to avoid running expensive hooks on every tool call:

- `"matcher": "Bash"` — only fires on Bash tool calls
- `"matcher": "Write|Edit"` — fires on Write or Edit tool calls
- `"matcher": "mcp__"` — fires on any MCP tool call
- Omit `matcher` — fires on every tool call

---

## Blocking Output Format

For `PreToolUse` hooks, exiting with code 2 blocks the action. You can provide a reason two ways:

**Simple (stderr message):**
```bash
echo "BLOCKED: reason here" >&2
exit 2
```

**Structured JSON (preferred):**
```bash
printf '{"decision": "block", "reason": "Explanation for Claude and user"}\n'
exit 0  # Exit 0 when using JSON output format
```

The JSON format is cleaner — Claude receives a structured explanation of why the block occurred.

---

## Hooks in This Repo

| Event | File | What It Does | Blocks? |
|-------|------|-------------|---------|
| `SessionStart` | `session-start/session-awareness.sh` | Shows all active Claude sessions, cleans stale ones, registers this session, shows cross-session event log | No |
| `SessionStart` | `session-start/janitor.sh` | TTL-based cleanup of temp files, rotates large JSONL logs. Runs once per day via sentinel. | No |
| `SessionStart` | `session-start/inject-git-state.sh` | Injects branch/dirty-files/recent-commits into session context via additionalContext. Saves tool calls at startup. | No |
| `PreToolUse` | `pre-tool/git-safety-check.sh` | Checks git version, prevents commits to home-dir repos, blocks large file staging | Yes (on error) |
| `PreToolUse` | `pre-tool/trust-gate.sh` | Gates publish/schedule actions behind a trust score matrix. Drafting always allowed. Email always blocked. | Yes (on low trust) |
| `PreToolUse` | `pre-tool/env-blocker.sh` | Hard blocks all Write/Edit operations targeting .env files | Yes (always) |
| `PostToolUse` | `post-tool/auto-diagnose.sh` | Pattern-matches Bash failures against 25+ error categories, prescribes the correct fix | No |
| `PostToolUse` | `post-tool/context-budget-warn.sh` | Counts tool calls, warns at 50/100/150/200 thresholds to trigger /compact | No |
| `PostToolUse` | `post-tool/post-deploy-healthcheck.sh` | Curls /health after deploy commands to verify the deployment is actually healthy | No |
| `Stop` | `stop/memory-extract.sh` | Calls Claude Haiku to extract novel insights from transcript, appends to daily memory file | No |

---

## The Self-Healing AI Runtime

Three hooks combine to create a runtime that corrects itself:

**1. auto-diagnose.sh** — Every Bash failure is categorized automatically. Instead of "Error: EADDRINUSE", Claude receives "[AUTO-DIAGNOSE] error=port_in_use / Fix: lsof -ti:3000 | xargs kill -9". The correct remedy is prescribed, not guessed.

**2. trust-gate.sh** — Autonomous publish actions are gated behind accumulated trust scores. As Claude's drafts get approved over time, trust increases and the gate opens. A new agent starts at zero autonomy and earns it. Trust can be revoked instantly.

**3. memory-extract.sh** — Every session's novel insights are extracted by Haiku and stored. Future sessions start with compound knowledge: root causes of past bugs, decisions already made, tool behaviors already discovered. The AI doesn't re-learn the same lessons.

Together: errors are diagnosed automatically, dangerous actions are gated, and knowledge compounds across sessions.

---

## Example: Full Session Lifecycle With All Hooks Active

```
User opens new terminal, runs: claude
  └── SessionStart fires:
      1. session-awareness.sh  — shows "2 other sessions active: ProjectA (3h ago), ProjectB (15min ago)"
      2. janitor.sh            — runs cleanup if first session today, silent otherwise
      3. inject-git-state.sh   — injects "Branch: feature/auth / 3 uncommitted files / last commit: fix: ..."

User asks Claude to commit changes:
  └── PreToolUse fires before "git commit":
      1. git-safety-check.sh   — verifies git version, no home-dir repo, no large files staged -> OK
      2. env-blocker.sh        — not a .env file -> pass-through

Bash runs, git commit succeeds:
  └── PostToolUse fires:
      1. auto-diagnose.sh      — exit_code=0, stays completely silent
      2. context-budget-warn.sh — 47 tool calls, below threshold, silent

User asks Claude to publish a social post:
  └── PreToolUse fires before "mcp__publishing__queue_put":
      1. trust-gate.sh         — checks trust.json, score=62 >= threshold=50 -> ALLOW

User ends the session:
  └── Stop fires:
      1. memory-extract.sh     — reads transcript, calls Haiku, extracts insights:
                                  "- [fix] git commit failed because index.lock existed; needed: rm .git/index.lock"
                                  appends to ~/.claude/memories/auto-20260413.md
```

---

## Quick Start

1. Copy the hooks you want to `~/.claude/hooks/`
2. Make them executable: `chmod +x ~/.claude/hooks/**/*.sh`
3. Add them to your `~/.claude/settings.json` using the JSON structure above
4. Open a new Claude Code session — hooks fire immediately
5. Test PreToolUse hooks: ask Claude to run a git commit and watch git-safety-check fire

For `trust-gate.sh`, create the trust file first:
```bash
mkdir -p ~/.claude/data
cat > ~/.claude/data/trust.json <<'EOF'
{
  "thresholds": { "routine_auto": 50, "supervised": 25 },
  "scores": {
    "platform_name": {
      "educational": 0,
      "promotional": 0
    }
  }
}
EOF
```

For `memory-extract.sh`, set your API key:
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```
