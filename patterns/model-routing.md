# Model Routing — Cost-Aware Intelligent Model Selection

## The Problem

Opus is ~15x more expensive per token than Haiku. Running every Claude Code operation through Opus is wasteful — most operations don't need it. But under-routing complex tasks to Haiku produces noticeably worse results: shallower analysis, missed edge cases, weaker architecture decisions.

Most teams solve this by picking one model for everything and accepting the tradeoff. A better approach routes each task to the right tier based on what the task actually requires.

## The Routing Tiers

| Tier | Model | Use For | Avoid For |
|------|-------|---------|-----------|
| **Heavy** | Opus | Architecture, security, complex refactors, planning | Search, simple reads, routine implementation |
| **Standard** | Sonnet | Feature implementation, bug fixes, API integration, moderate reasoning | Simple searches, pure documentation |
| **Light** | Haiku | Search, grep, file reads, doc writing, dependency audits | Anything requiring judgment or complex reasoning |

## Routing Signals

### Keyword signals
These keywords in the task description suggest a model tier:

**Opus keywords**: "architecture", "design system", "security audit", "migrate all", "refactor entire", "evaluate tradeoffs", "what should we use", "review for vulnerabilities", "complex", "strategic"

**Haiku keywords**: "search for", "find all", "list", "grep", "read", "check if", "count", "what files", "explore", "scan"

**Sonnet**: everything else (the default)

### Task complexity signals

| Signal | Suggested Tier |
|--------|---------------|
| Touching 1-2 files | Sonnet or below |
| Touching 3-10 files | Sonnet |
| Touching 10+ files or architectural scope | Opus |
| Decision between multiple approaches | Opus |
| Implementation of a decided approach | Sonnet |
| Search/read with no writes | Haiku |
| Security-sensitive path | Opus |

### Agent type signals

Certain agent roles always map to a specific tier regardless of the task:

| Agent | Model | Why |
|-------|-------|-----|
| orchestrator | Opus | Decomposition requires strong reasoning |
| planner | Opus | Architecture decisions require depth |
| security-reviewer | Opus | Security judgment cannot be compromised |
| refactorer | Opus | Cross-file analysis requires full context |
| builder | Sonnet | Implementation is standard-complexity |
| verifier | Sonnet | Testing logic is moderate-complexity |
| deployer | Sonnet | Deployment is procedural |
| explorer | Haiku | Search is lightweight |
| scribe | Haiku | Documentation is lightweight |
| dependency-updater | Haiku | Package auditing is lightweight |

## Cost Impact at Scale

In a typical intensive day: 50+ agent dispatches, 30-40 of which are Explore/search tasks.

Without routing (all Opus):
- 50 operations × Opus cost = baseline

With routing (Haiku for searches, Sonnet for implementation, Opus for decisions):
- 35 Haiku ops × 1/15th cost + 10 Sonnet ops × 1/5th cost + 5 Opus ops = ~20% of baseline

**Routing cuts costs by ~80% on a typical heavy-use day** with no meaningful quality loss on the tasks that go to lighter models.

## Applying Routing in Practice

### In agent definitions

Set the model in each agent's frontmatter:
```markdown
---
name: explorer
model: claude-haiku-4-5-20251001
description: Fast read-only codebase investigation
---
```

### In agent dispatch prompts

Include a model hint when dispatching via the Agent tool:
```
Agent({
  subagent_type: "Explore",
  model: "haiku",
  prompt: "Find all TypeScript files that import from src/auth"
})
```

### In the orchestrator pattern

The orchestrator uses Opus to decompose and assign. When it creates tasks, it specifies the model tier for each specialist it dispatches. The planner thinks in Opus. The builders execute in Sonnet. The searchers scan in Haiku.

## Override Rule

User instructions always beat routing logic. If the user explicitly requests a model ("use Haiku for this"), that's the model — regardless of what the routing logic suggests.

If you're unsure whether a task warrants Opus vs Sonnet, default to Sonnet. The quality gap between Sonnet and Opus is smaller than the quality gap between Haiku and Sonnet for most implementation tasks.

## Implementation

Model assignments are specified in each agent's frontmatter in the [`agents/`](../agents/) directory. The routing logic lives in your CLAUDE.md model routing section.
