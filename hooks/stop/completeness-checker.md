---
hook_type: Stop
event: Stop
description: Reviews whether all tasks from the user's request were actually completed before Claude exits
output_format: prompt
---

# Completeness Checker — Stop Hook

A Stop hook that reviews the conversation before Claude exits to verify all user requests were fulfilled. If items are missing, it outputs a prompt reminding Claude to complete them before stopping.

## What This Hook Does

When Claude is about to stop, this hook reads back through the conversation and checks:
1. What did the user actually ask for?
2. Was each request fulfilled (file written, command run, output confirmed, etc.)?
3. Are there any incomplete items that should block the stop?

If everything is done, the hook returns nothing (Claude stops normally).
If items are missing, the hook outputs a reminder prompt that Claude processes before exiting.

## The Prompt Text

Paste this prompt text into your hook configuration:

```
Before you stop, review the conversation and verify every request is complete.

Step 1: List what the user asked for.
Scan the conversation from the beginning. Extract every distinct task, question, or request the user made. Be specific — "write a function" is a task; "thanks" is not.

Step 2: Check each item.
For each item from Step 1, determine its status:
- DONE: The output was explicitly produced (file written, command run, answer given, result confirmed)
- PENDING: You started it but didn't finish (partial output, cut off, promised but not delivered)
- BLOCKED: Cannot complete without user input (needs a password, credential, business decision, or explicit approval)
- SKIPPED: User explicitly said to skip, defer, or approved stopping without it

Step 3: Decide.
- If ALL items are DONE, BLOCKED, or SKIPPED: stop normally. Output nothing.
- If ANY items are PENDING: do NOT stop. Complete the pending items now, then stop.

Exceptions — these allow stopping even if incomplete:
1. Credential blocks: the task requires a secret or API key the user hasn't provided
2. Explicit user approval to stop: user said "that's enough", "stop here", "we can do the rest later"
3. Deployment gates: the task requires a human action in an external system (clicking approve, merging a PR) before the next step can run
4. Clarifying questions: you asked the user a question that must be answered before you can proceed, and they haven't answered yet

If you find a pending item that doesn't qualify for an exception, complete it now before stopping.
```

## Installation

### In Claude Code (settings.json)

Add to your `~/.claude/settings.json` under the `hooks` section:

```json
{
  "hooks": {
    "Stop": [
      {
        "type": "prompt",
        "prompt": "Before you stop, review the conversation and verify every request is complete.\n\nStep 1: List what the user asked for.\nScan the conversation from the beginning. Extract every distinct task, question, or request the user made. Be specific — \"write a function\" is a task; \"thanks\" is not.\n\nStep 2: Check each item.\nFor each item from Step 1, determine its status:\n- DONE: The output was explicitly produced (file written, command run, answer given, result confirmed)\n- PENDING: You started it but didn't finish (partial output, cut off, promised but not delivered)\n- BLOCKED: Cannot complete without user input (needs a password, credential, business decision, or explicit approval)\n- SKIPPED: User explicitly said to skip, defer, or approved stopping without it\n\nStep 3: Decide.\n- If ALL items are DONE, BLOCKED, or SKIPPED: stop normally. Output nothing.\n- If ANY items are PENDING: do NOT stop. Complete the pending items now, then stop.\n\nExceptions — these allow stopping even if incomplete:\n1. Credential blocks: the task requires a secret or API key the user hasn't provided\n2. Explicit user approval to stop: user said \"that's enough\", \"stop here\", \"we can do the rest later\"\n3. Deployment gates: the task requires a human action in an external system before the next step can run\n4. Clarifying questions: you asked the user a question that must be answered before you can proceed"
      }
    ]
  }
}
```

### As a Shell Script Hook

Alternatively, if you prefer a shell script that outputs the prompt conditionally:

```bash
#!/usr/bin/env bash
# hooks/stop/completeness-checker.sh
# Outputs the completeness-check prompt; Claude processes it before stopping.

cat <<'EOF'
Before you stop, review the conversation and verify every request is complete.

Step 1: List what the user asked for.
Extract every distinct task, question, or request the user made.

Step 2: Check each item against these statuses:
- DONE: output explicitly produced and confirmed
- PENDING: started but not finished
- BLOCKED: needs user input (credentials, decisions, approvals)
- SKIPPED: user said to skip or defer

Step 3: If ALL items are DONE, BLOCKED, or SKIPPED — stop.
If ANY are PENDING — complete them first, then stop.

Allowed exceptions (may stop even if incomplete):
1. Missing credentials the user hasn't provided yet
2. User explicitly approved stopping early
3. Task blocked on external system action (merge, deploy approval)
4. Unanswered clarifying question blocks next step
EOF
```

Make executable: `chmod +x hooks/stop/completeness-checker.sh`

## Why This Matters

The most common failure mode in multi-task conversations is Claude stopping after the first task and not completing the rest. This hook acts as a final gate — a forced review before exit that catches:

- Tasks that were mentioned once and then forgotten
- Partial implementations (function written, but imports not updated)
- Promises made but not kept ("I'll do X after Y" where Y ran long)
- Files written but TypeScript not compiled to verify they're clean

## Tuning

If the hook is too aggressive (triggering on conversations where Claude legitimately finished), tighten the exception list. If it's not catching enough, remove the exceptions and require explicit user confirmation to stop when any item is pending.

The "Step 3: Decide" logic is intentionally binary — DONE or not DONE. No partial credit. This matches the standard for verified completeness used throughout these skills.
