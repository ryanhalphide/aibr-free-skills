# AIBR Agent Framework

**An open-source AI engineering platform for Claude Code — built from 12 months of production use.**

30 skills · 12 specialist agents · 10 lifecycle hooks · 7 architectural patterns

[Install in 30 seconds](#installation) · [Browse Skills](#skills) · [Agent Hierarchy](#agents) · [Hook System](#hooks)

---

## What This Is

This is a complete Claude Code automation ecosystem — not a collection of prompt files. Skills orchestrate agents. Agents have specialized roles with explicit tool allowlists. Hooks create a self-healing runtime that catches errors before they become problems. Patterns document the design decisions that make the whole system coherent.

Most Claude Code setups are a flat folder of markdown commands. This framework treats Claude Code as a runtime environment with distinct layers: commands that delegate to specialized sub-agents, lifecycle hooks that enforce guardrails automatically, and an architectural pattern library that documents *why* the system is built the way it is. The result is a Claude Code setup that behaves consistently across projects and scales to complex multi-agent workflows.

Everything here was extracted from real production work — debugging voice agents, building data pipelines, shipping full-stack applications, managing multi-repo client engagements. Nothing was designed in the abstract. If a pattern is in this repo, it earned its place by solving a real problem that cost real time to discover.

---

## Architecture

```
                        ┌─────────────────────────────────┐
                        │           User Input             │
                        │    /skill command or free text   │
                        └─────────────────┬───────────────┘
                                          │
                        ┌─────────────────▼───────────────┐
                        │             Skills               │
                        │  /commands — 30 skill files      │
                        │  Orchestrate work, set context,  │
                        │  dispatch to specialist agents   │
                        └──────┬──────────────────┬───────┘
                               │                  │
               ┌───────────────▼──┐  ┌────────────▼──────────────┐
               │     Agents       │  │          Hooks             │
               │  12 specialist   │  │   10 lifecycle scripts     │
               │  roles, each     │  │   PreToolUse, PostToolUse  │
               │  scoped to a     │  │   Stop, SessionStart       │
               │  tool allowlist  │  │   Self-healing runtime     │
               └───────────────┬──┘  └────────────┬──────────────┘
                               │                  │
                        ┌──────▼──────────────────▼──────┐
                        │            Patterns             │
                        │   7 documented architecture     │
                        │   decisions — the "why"         │
                        │   behind every design choice    │
                        └─────────────────────────────────┘

  Skill categories:     Agent model tiers:      Hook events:
  ─────────────────     ────────────────────    ────────────────
  Debugging     (4)     Opus   → planning,      PreToolUse
  Git           (2)             security,        PostToolUse
  Code Quality  (2)             arch decisions   Stop
  Planning      (2)     ─────────────────────   SessionStart
  Productivity  (4)     Sonnet → code changes,
  Multi-Agent   (3)             implementation,
  Knowledge     (4)             API work
  Research      (2)     ─────────────────────
  Video         (2)     Haiku  → search,
  Deployment    (3)             diagnostics,
  Social        (2)             lightweight reads
```

The flow is intentional: skills are the interface, agents are the workers, hooks are the safety net, patterns are the documentation. Each layer has a single responsibility. No agent modifies `.env` files. No hook blocks valid work. Every skill declares its scope upfront.

---

## Installation

```bash
git clone https://github.com/[your-github-username]/aibr-free-skills.git
cd aibr-free-skills
chmod +x install.sh && ./install.sh
```

The installer symlinks skills into `~/.claude/commands/` and agents into `~/.claude/agents/`. Hooks are not auto-wired — the installer prints the exact JSON snippets to paste into your `settings.json`. This is intentional: hooks fire on every matching tool call, so you should consciously opt in to each one.

**Requirements:** Claude Code must be installed and `~/.claude/` must exist.

**Options:**
```bash
./install.sh --dry-run   # Preview what would be installed without making changes
./install.sh --force     # Overwrite existing symlinks
```

---

## Skills

Skills are invoked as `/skill-name` slash commands in Claude Code. Each skill file defines its scope, the tools it may use, and a step-by-step process. Complex skills delegate to specialist agents automatically — you get the result without managing the handoff.

### Debugging

| Skill | Description |
|---|---|
| `/quick-debug` | Hypothesis-first bug triage — reads error, checks git log, generates 3 ranked root causes, verifies the top one, applies a targeted fix |
| `/frustrated` | Resets context when stuck — lists attempts so far, forces a completely different approach |
| `/fix-tests` | Diagnoses failing tests without shotgun patching — identifies the specific breaking change and proposes a minimal fix |
| `/auto-debug` | Full autonomous debug loop — hypothesize, design cheapest test, confirm, fix, post-mortem |

### Git

| Skill | Description |
|---|---|
| `/smart-commit` | Generates semantic commit messages from the actual diff, stages intelligently, handles pre-commit hook failures without losing work |
| `/pr` | Creates a full PR with title, summary, test plan, and appropriate labels |

### Code Quality

| Skill | Description |
|---|---|
| `/project-scanner` | Five-point health audit — env vars, dependency health, security vulnerabilities, dead code, code quality signals. Scored report, nothing auto-fixed |
| `/fix-ci` | Diagnoses CI failures from raw logs, proposes a targeted fix without touching unrelated code |

### Planning

| Skill | Description |
|---|---|
| `/discovery` | Read-only project exploration — builds a complete mental model of the codebase before any writes happen |
| `/scaffold-claude-md` | Generates a project-specific CLAUDE.md from codebase analysis — stack detection, conventions, gotchas |

### Productivity

| Skill | Description |
|---|---|
| `/go` | Session starter — loads active context, resumes in-progress work, morning briefing mode |
| `/next` | Surfaces the single highest-priority next action from all open tasks |
| `/outstanding` | Full picture of in-progress work, blocked items, and pending decisions |
| `/preflight` | Pre-work checklist — confirms correct branch, env vars set, tests passing, dependencies installed |

### Multi-Agent

| Skill | Description |
|---|---|
| `/swarm` | Spawns N parallel agents for independent subtasks, collects and reconciles results |
| `/sprint` | Sequential specialist pipeline — explore then build then verify then deploy, each phase handoff explicit |
| `/hive` | Multi-terminal swarm coordination via file-based state — no network required (see Hive Coordination pattern) |

### Knowledge

| Skill | Description |
|---|---|
| `/graphify` | Converts any input (docs, transcripts, meeting notes, URLs) into a structured knowledge graph |
| `/wiki-ingest` | Ingests a URL or file into the project wiki with auto-tagging |
| `/wiki-query` | Answers questions from the project wiki with citations, not hallucinations |
| `/wiki-lint` | Audits the wiki for stale entries, broken links, and missing context |

### Research

| Skill | Description |
|---|---|
| `/auto-research` | Autonomous optimization loop — mutate, experiment, measure, keep or discard. Adapted from Karpathy's autoresearch pattern (see CREDITS.md) |
| `/creative-edge` | Generates unconventional approaches by systematically breaking constraints and inverting assumptions |

### Video

| Skill | Description |
|---|---|
| `/remotion` | Scaffolds and iterates Remotion video components with composition structure and timing |
| `/video-iterate` | Applies feedback to a rendered video — frame-accurate editing loop with visual diff |

### Deployment

| Skill | Description |
|---|---|
| `/deploy` | Runs deployment with pre-flight checks, branch verification, and env confirmation before any push |
| `/deploy-verify` | Post-deploy health check — probes live endpoints, checks logs, confirms the right version is live |
| `/system-health` | Full system status report — services, queues, scheduled jobs, recent errors, disk and memory |

### Social

| Skill | Description |
|---|---|
| `/social-draft` | Drafts platform-specific social content (LinkedIn, X, Instagram) from a brief |
| `/social-campaign` | Builds a multi-post campaign with scheduling, variant copy, and cross-platform adaptation |

---

## Agents

The framework uses a 12-role agent hierarchy. Each agent has a defined scope, an explicit tool allowlist, and a model tier assignment. Specialization is the point — narrow scope produces more reliable output than general-purpose agents.

| Agent | Role | Model Tier |
|---|---|---|
| `planner` | Writes saved-plan.md for complex multi-phase tasks, aligns on approach before execution | Opus |
| `security-reviewer` | Audits code for vulnerabilities, auth gaps, injection risks, exposed secrets | Opus |
| `rh-reviewer` | Full code review with tradeoffs, alternatives, and explicit severity ratings | Opus |
| `feature-dev` | Full feature implementation across multiple files with cross-file import updates | Sonnet |
| `builder` | Targeted 1-2 file edits, minimal-footprint implementation | Sonnet |
| `verifier` | Runs tests, typechecks, build verification — reports pass/fail with evidence | Sonnet |
| `deployer` | Deployment execution and post-deploy confirmation, never touches source code | Sonnet |
| `plugin-dev` | Claude Code plugin and skill development, knows the skill spec format | Sonnet |
| `code-reviewer` | Targeted review of a specific diff or file, fast turnaround | Sonnet |
| `rh-explorer` | Read-only codebase investigation — no writes, no side effects, pure analysis | Haiku |
| `researcher` | Web research, documentation lookup, and synthesis across sources | Haiku |
| `diagnostics` | Log tailing, health checks, grep and search tasks — speed over depth | Haiku |

**Model routing rationale:** Opus for decisions that are expensive to reverse (architecture, security reviews, complex planning). Sonnet for implementation work. Haiku for read-only and diagnostic work where speed matters more than depth. This is the Model Routing pattern — documented in detail in `/patterns/model-routing.md`.

---

## Hooks

Hooks are shell scripts wired into Claude Code's lifecycle events. They fire automatically on every matching tool call — no skill invocation required. The hook system turns Claude Code from a reactive tool into a proactive one that catches problems before they land in the conversation.

**How to wire hooks:** The installer prints the exact JSON snippets to paste into `~/.claude/settings.json`. See `hooks/README.md` for full instructions and the complete hook reference.

### Hook Events

| Event | When It Fires | Use Cases |
|---|---|---|
| `PreToolUse` | Before any tool call — can block or warn | Branch protection, secret scanning, disk space checks |
| `PostToolUse` | After any tool call — can log or trigger side effects | Error diagnosis, test triggering, deploy verification |
| `Stop` | When Claude finishes a response | Memory extraction, session logging |
| `SessionStart` | At the start of a new session | Context loading, trust score initialization |

### The 3 Most Novel Hooks

**auto-diagnose** (`hooks/post-tool/auto-diagnose.sh`)

A self-healing error categorizer. After any Bash tool call that exits non-zero, it reads the error output and matches it against 25+ failure mode signatures — auth errors, missing dependencies, build failures, network issues, permission errors, rate limits, and more. A structured diagnosis is injected into the next context window. Claude sees a categorized error type with a suggested first step, not just raw stderr. This eliminates the "retry the same command" loop that burns time in every debugging session.

**trust-gate** (`hooks/pre-tool/trust-gate.sh`)

Progressive autonomy based on a session-scoped trust score. New sessions start at a cautious level — destructive operations (force-push, DROP TABLE, rm -rf, production deploys) require explicit user confirmation. As the session progresses and the user approves actions, the trust score rises and confirmation prompts become less frequent. The score is persisted per-project in `~/.claude/cache/`. Think of it as a dial between "confirm everything" and "maximum initiative" that you earn during a session.

**memory-extract** (`hooks/stop/memory-extract.sh`)

AI-powered session distillation via the Claude Haiku API. When Claude finishes a response (Stop event), this hook sends the last N tool calls and outputs to Haiku with a structured extraction prompt. Haiku identifies decisions, surprises, and non-obvious learnings worth preserving across sessions, then writes them to the memory pipeline. The result: sessions self-document. You get persistent memory without manually running a `/session-end` command.

---

## Patterns

Seven architectural patterns are documented in `/patterns/`. Each is a standalone document explaining a design decision: the problem it solves, how it works, the tradeoffs, and when to use it.

| Pattern | Description |
|---|---|
| **Trust Gate** | Progressive AI autonomy via a session-scoped trust score. Blocks destructive ops at low trust, reduces friction as trust is earned through the session. |
| **Auto-Diagnose** | Self-healing error categorization with 25+ failure mode signatures. Structured diagnosis injected into context eliminates retry loops. |
| **Hive Coordination** | File-based multi-terminal swarm. Multiple Claude Code sessions coordinate via a shared state directory — no network, no server required. |
| **Agent Specialization** | The 12-role hierarchy design: why narrow scope outperforms generalists, how to assign tool allowlists, model tier selection criteria. |
| **Memory Pipeline** | How sessions produce persistent memory: Stop hook fires, Haiku extracts, memory file is written, MEMORY.md index is updated, next session loads it. |
| **Model Routing** | Cost-aware intelligent model selection. Decision tree for routing tasks to Opus, Sonnet, or Haiku based on reversibility, complexity, and time sensitivity. |
| **Hook Lifecycle** | The complete event-driven Claude Code runtime. How PreToolUse, PostToolUse, Stop, and SessionStart compose into a coherent safety and automation layer. |

---

## About AIBR

AI Boost Realization builds production AI tooling for developers and teams.

- Website: [aibr.pro](https://aibr.pro)
- GitHub: [github.com/[your-github-username]](https://github.com/[your-github-username])
- Agent Empire: [agentbuilder.aibr.pro](https://agentbuilder.aibr.pro)
- Agent Academy: [agents.aibr.pro](https://agents.aibr.pro)

---

## License

MIT — free to use, share, and fork. Attribution appreciated.

See [CREDITS.md](./CREDITS.md) for third-party attributions.
