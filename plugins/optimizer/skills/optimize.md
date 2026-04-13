---
name: optimize
description: Analyze your Claude Code workspace for inefficiencies and generate a prioritized optimization plan — hook gaps, model routing opportunities, missing skills, config improvements
allowed-tools: ["Read", "Bash", "Glob", "Grep"]
user_invocable: true
argument-hint: "[--quick | --deep | --focus hooks|skills|config|costs]"
---

# /optimize — Workspace Optimizer

Audits your Claude Code configuration, skill coverage, and usage patterns to produce a prioritized list of improvements. Read-only — never modifies your configuration.

## Step 1: Parse Arguments

- `--quick`: Checks 1-2 only (config + hooks gap). Fastest.
- `--deep`: All 5 checks plus reads recent session transcripts.
- `--focus [area]`: Runs only the specified check.

Default: all 5 checks.

## Step 2: Configuration Audit

Read `~/.claude/settings.json`. Check for:

**Hook coverage gaps** (critical — these are automations that can't run if not wired):
```bash
# Check which hooks are configured
grep -c "SessionStart\|PreToolUse\|PostToolUse\|Stop\|PreCompact" ~/.claude/settings.json 2>/dev/null || echo "0 hook types configured"
```

Flag as missing:
- No `SessionStart` hooks → no automated context injection
- No `PostToolUse` hook on Bash → no auto-diagnosis of failures
- No `Stop` hook → no memory extraction
- No `PreToolUse` hook → no safety gates on dangerous operations

**Model configuration**:
- Is model routing configured (different models for different agents)?
- Is `alwaysThinkingEnabled` set (adds extended reasoning)?
- Is `CLAUDE_CODE_MAX_TOOL_CALLS` set above default (100+)?

**Permission configuration**:
- Are `.env`, `.ssh`, `.aws` directories blocked from writes?
- Is force-push to main blocked?
- Are there allow rules broad enough to bypass safety checks?

## Step 3: Skill Coverage Gap Analysis

```bash
ls ~/.claude/commands/ 2>/dev/null | head -50
ls ~/.claude/skills/ 2>/dev/null | head -30
```

Check for missing coverage in each category:
- **Debugging**: quick-debug, frustrated, fix-tests?
- **Git**: smart-commit, pr workflow?
- **Planning**: discovery, scaffold-claude-md?
- **Deployment**: deploy, deploy-verify?
- **Multi-agent**: swarm or sprint for parallel work?
- **Knowledge**: graphify for knowledge graph generation?
- **Session management**: go, preflight, next?

## Step 4: Agent Specialization Check

```bash
ls ~/.claude/agents/ 2>/dev/null | head -20
```

Flag if:
- No agents defined → using only general-purpose agents (loses specialization benefits)
- Missing key roles: no security-reviewer (security gap), no verifier (testing gap), no explorer (relying on heavy models for search)
- All agents using same model (no cost optimization)

## Step 5: Usage Pattern Analysis (--deep only)

```bash
# Find recent session files
ls -lt ~/.claude/projects/ 2>/dev/null | head -20
```

Look for repeated patterns in recent sessions:
- Same error types appearing multiple times → hook could automate the fix
- Same manual workflow repeated → skill opportunity
- Long exploration sequences using heavy models → should use Haiku explorer agent

## Step 6: Generate Report

Write to `~/.claude/optimizer/latest-report.md`:

```markdown
# Claude Code Optimization Report
Generated: [date]

## Score: [0-100]
Based on: hook coverage (40pts), skill coverage (25pts), agent setup (20pts), config (15pts)

## Quick Wins (< 30 min each)
1. [Specific action] — [Expected improvement]
   - Current state: [what's missing]
   - Fix: [exact change to make]

## Medium Improvements (half-day)
...

## Long-term (architectural)
...

## What's Working Well
...
```

Print the report path and a brief summary of the top 3 quick wins.
