# Hook Lifecycle — Event-Driven Claude Code Runtime

## The Problem

Claude Code's default behavior is a linear request-response loop. There's no persistent state between tool calls, no automatic quality gates, no self-healing, no lifecycle management. You can add behaviors through prompting, but prompts are ephemeral — they're forgotten after compaction, can't run shell commands, and can't block actions before they happen.

The result: every session starts blank. Mistakes repeat. Dangerous operations go unchecked. Insights evaporate. The quality of your Claude Code sessions is determined entirely by what you remember to ask for.

Hooks solve this. They turn Claude Code from a stateless assistant into an event-driven runtime.

## The Hook System

Hooks are shell scripts (or prompt injections) wired into `settings.json` that execute at specific lifecycle events. They run outside Claude's context — in your shell — so they can:
- Read and write files
- Run arbitrary commands
- Call external APIs
- Block tool calls before they execute
- Inject additional context into Claude's prompt

## Complete Event Lifecycle

```
Session opens
    │
    ▼
[SessionStart hooks]
  Run shell scripts that inject context, validate environment,
  coordinate with other sessions, clean up stale files.
  Examples: session-awareness.sh, janitor.sh, inject-git-state.sh
    │
    ▼
User sends message → [UserPromptSubmit hooks]
  Can inject additional context before Claude processes the prompt.
  Examples: auto-memory-search (injects past relevant context)
    │
    ▼
Claude plans → calls tool → [PreToolUse hooks]
  Can BLOCK the tool call. Runs before every Bash, Write, Edit, etc.
  Output {"decision": "block", "reason": "..."} to block.
  Examples: trust-gate.sh (blocks low-trust publishes), env-blocker.sh
    │
    ▼
Tool executes
    │
    ▼
[PostToolUse hooks]
  Cannot block (already happened). Runs after every tool call.
  On success: usually silent (no output = no context cost).
  On failure: categorize the error, prescribe a fix.
  Examples: auto-diagnose.sh, post-deploy-healthcheck.sh
    │
    ▼
Claude stops → [Stop hooks]
  Runs before session ends. Can inject a prompt to continue.
  Use for: memory extraction, completeness checking.
  Examples: memory-extract.sh, completeness-checker
    │
    ▼
[PreCompact hooks]
  Runs before context compaction.
  Use for: saving plan state, key findings, task progress.
    │
    ▼
Context compacted → session continues or ends
```

## Hook Output Formats

### Blocking a tool (PreToolUse only)
```json
{"decision": "block", "reason": "Cannot write to .env files. Edit manually and restart."}
```

### Injecting context (any hook)
```json
{"prompt": "Before proceeding, note that the last deployment to staging failed health checks."}
```

### Silent success
Exit 0 with no output. Zero context cost. The tool proceeds.

### Error in hook
If the hook itself fails (non-zero exit), Claude is notified but the tool call proceeds. Hook failures don't block operations — they surface for awareness.

## Settings.json Wiring

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "~/.claude/hooks/session-start/session-awareness.sh"
      },
      {
        "type": "command",
        "command": "~/.claude/hooks/session-start/janitor.sh"
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "type": "command",
        "command": "~/.claude/hooks/pre-tool/git-safety-check.sh"
      },
      {
        "matcher": "Write",
        "type": "command",
        "command": "~/.claude/hooks/pre-tool/env-blocker.sh"
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "type": "command",
        "command": "~/.claude/hooks/post-tool/auto-diagnose.sh"
      }
    ],
    "Stop": [
      {
        "type": "command",
        "command": "~/.claude/hooks/stop/memory-extract.sh"
      }
    ]
  }
}
```

The `matcher` field filters by tool name. Omit `matcher` to run on all tool calls.

## Composing Multiple Hooks

Multiple hooks for the same event run in sequence. For PreToolUse:
- If any hook returns `{"decision": "block"}`, the tool does NOT run
- Hooks run in the order listed in settings.json
- A hook failure (non-zero exit) surfaces to Claude but doesn't automatically block

Keep each hook focused on one concern. One hook for git safety, one for .env protection, one for trust-gating. This makes them individually testable and easy to enable/disable.

## The Self-Healing Runtime

The three hooks that create a self-healing runtime:

1. **auto-diagnose.sh** (PostToolUse on Bash failures): categorizes errors, prescribes fixes
2. **trust-gate.sh** (PreToolUse): gates autonomous actions based on accumulated trust
3. **memory-extract.sh** (Stop): distills session learnings for future context

Together: errors get fixed faster, dangerous actions stay gated, learnings compound. Claude Code becomes a platform with persistent behaviors rather than a stateless assistant.

## Implementation

See: [`hooks/`](../hooks/) directory. `hooks/README.md` has the complete wiring guide.
