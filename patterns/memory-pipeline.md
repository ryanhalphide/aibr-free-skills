# Memory Pipeline — Turning Ephemeral Sessions into Compound Knowledge

## The Problem

Claude Code sessions are ephemeral. Every session starts fresh. Insights, debugging solutions, architectural decisions, workflow discoveries — all of it evaporates when the session ends.

After 12 months of daily intensive use, you should be smarter than you were on day 1. Your setup should remember the bug that took 3 hours to debug. It should know which workaround you found for the N8N webhook header format. It should carry forward the decision you made last Tuesday about database schema design.

Without a memory system, you don't compound. Every session is day 1.

## The Pattern

A three-stage pipeline that runs automatically at session end:

```
Session transcript
      │
      ▼
[Stop hook: memory-extract.sh]
      │ Calls Claude Haiku API to extract novel insights
      ▼
Daily memory file (structured, with frontmatter)
      │
      ▼
[PostToolUse hook: memory-index-update.sh]
      │ Adds pointer to MEMORY.md index
      ▼
MEMORY.md (loaded at every SessionStart)
      │
      ▼
Future sessions start with today's learnings pre-loaded
```

## Stage 1: Extract

The `memory-extract.sh` Stop hook:
1. Reads the session transcript from Claude Code's session files
2. Calls Claude Haiku via the API (headless, non-interactive) with a structured extraction prompt
3. The prompt asks Haiku to identify: fixes with non-obvious root causes, decisions to use pattern X over Y and why, tool configurations that solved persistent problems, workflow discoveries, gotchas and edge cases

Haiku is fast and cheap enough to run on every session — the extraction costs fractions of a cent and runs in the background without blocking.

**What makes a good insight:**
- A bug fix where the root cause was non-obvious (e.g., the git lock file issue, the N8N webhook header format)
- A decision with reasoning (e.g., "chose Drizzle over Prisma because Turso requires libSQL compatibility")
- A configuration discovery (e.g., "CLAUDE_CODE_MAX_TOOL_CALLS=500 prevents premature stopping on large tasks")
- A workflow that saved significant time

**What's not worth extracting:**
- Standard implementations (writing a React component, setting up a route)
- Routine task completions ("fixed the TypeScript error on line 42")
- Anything already in the official docs

## Stage 2: Store

Extracted insights are written to daily memory files with structured YAML frontmatter:

```markdown
---
name: n8n-webhook-header-format
type: feedback
date: 2026-01-15
session_id: abc123
project: your-project
---

# N8N Webhook v2 Header Format

N8N webhook v2 nests the body under `.body` in the Code node, not at the root.
Use `$input.first().json.body.field` not `$input.first().json.field`.

**Why it matters:** This breaks silently — the webhook receives the request but the
field access returns undefined with no error.

**How to apply:** Always check N8N version when writing webhook Code nodes. v2 webhooks
need the `.body` prefix; v1 webhooks don't.
```

## Stage 3: Index

The MEMORY.md index is updated with a one-line pointer:

```markdown
- [N8N webhook v2 body nesting](path/to/feedback_n8n-webhook-header.md) — `.body` prefix required in Code nodes; silently fails without it
```

MEMORY.md is loaded by Claude at every SessionStart (it's in the CLAUDE.md or injected via hook). The index is kept under 200 lines — if it grows beyond that, older entries are archived and a summary is added.

## The Compound Effect

After 6 months:
- MEMORY.md has 150+ pointers to validated learnings
- New sessions start with the most relevant context pre-loaded
- Claude doesn't repeat mistakes it made 3 months ago
- Debugging sessions get shorter because past solutions surface automatically
- Architecture decisions are consistent because past reasoning is available

The compound effect is real: a system with 6 months of memory is qualitatively different from one starting fresh every day. It behaves more like a long-term collaborator than a stateless assistant.

## Auto-Triggered Memory Search

A complementary UserPromptSubmit hook can auto-search episodic memory based on keywords in each prompt. Before Claude responds to "fix the webhook timeout issue," the hook searches memory for past webhook fixes and injects any relevant context. This closes the loop: insights extracted at Stop become context injected at the next relevant UserPromptSubmit.

## Implementation

See: [`hooks/stop/memory-extract.sh`](../hooks/stop/memory-extract.sh)
