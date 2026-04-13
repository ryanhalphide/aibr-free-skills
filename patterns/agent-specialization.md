# Agent Specialization — The 12-Role Hierarchy

## The Problem

A general-purpose AI agent that plans, codes, tests, reviews, and deploys simultaneously loses coherence. It violates separation of concerns. Without a clear scope, it makes unauthorized changes, second-guesses its own decisions, and blurs the boundary between "thinking about what to do" and "doing it."

The symptom: you ask Claude to fix a bug, and it refactors three adjacent files, updates the tests, revises the API docs, and changes the deployment config — none of which you asked for. It also misses the actual bug because it was context-switching across too many concerns.

The fix isn't better prompting. It's architectural: narrow the scope at the agent definition level.

## The Pattern

12 specialized agents, each with:
- A **single responsibility** — one thing it does, and an explicit list of what it cannot do
- A **tool allowlist** — only the tools needed for its role (a reviewer without Write/Edit *cannot* make unauthorized changes — the constraint is structural, not instructional)
- A **model tier** — matched to the cognitive complexity of the role
- A **scope declaration** — what files/directories it can touch

An orchestrator decomposes work and delegates to specialists. Specialists execute and report back. Specialists don't make decisions outside their scope.

## The 12 Roles

| Agent | Model | Does | Cannot Do |
|-------|-------|------|-----------|
| **orchestrator** | Opus | Decomposes goals, creates tasks, delegates to specialists, tracks progress | Write or edit code, make architectural decisions alone |
| **planner** | Opus | Architecture analysis, implementation plans, risk assessment, writes plan files | Edit any code, make unilateral decisions |
| **builder** | Sonnet | Implements features, fixes bugs, creates migrations | Write tests, documentation, or deploy |
| **verifier** | Sonnet | Runs tests, typecheck, lint, adds missing test coverage | Edit implementation files |
| **reviewer** | Sonnet | Code quality review, bug spotting, security flags, architecture feedback | Make any changes — suggests only |
| **security-reviewer** | Opus | Security audit, credential leak detection, injection vulnerability analysis | Make changes — reports only |
| **deployer** | Sonnet | Deploys to Railway, Vercel, Fly.io, runs health checks | Edit code |
| **explorer** | Haiku | Read-only codebase investigation, search, path tracing, architecture mapping | Edit anything |
| **scribe** | Haiku | Documentation, README, changelog, API docs — markdown only | Edit code files |
| **migrator** | Sonnet | Database schema migrations, rollback scripts, migration testing | Edit application code |
| **refactorer** | Opus | Cross-file structural refactoring, renames, moves, dependency updates | Add new features |
| **dependency-updater** | Haiku | Audit packages, plan updates, run updates in batches, revert on test failure | Edit application code |

## Model Routing Rationale

**Opus** for agents that make decisions: orchestrator (decomposition), planner (architecture), security-reviewer (judgment calls), refactorer (complex cross-file analysis). These require the strongest reasoning.

**Sonnet** for agents that implement: builder, verifier, deployer, migrator. These require solid code generation and execution but not architectural reasoning.

**Haiku** for agents that search and read: explorer, scribe, dependency-updater. These are high-volume, low-complexity tasks. Routing them to Haiku instead of Sonnet/Opus cuts token costs by 60-70% with no quality loss on search/scan work.

## Tool Allowlists Matter

A reviewer agent with tools `["Read", "Glob", "Grep", "Bash"]` and without `Write` or `Edit` literally **cannot** make unauthorized file changes. This is architectural enforcement, not an instruction that can be overridden by a clever prompt.

Compare:
- Instruction-only: "As a reviewer, don't make changes." (Can be overridden by context)
- Tool allowlist: `allowed-tools: ["Read", "Glob", "Grep"]` (Cannot make changes — tools don't exist)

Every agent in this framework uses explicit tool allowlists. The scope is enforced at the infrastructure level.

## Orchestrator → Specialist Workflow

```
User: "Add OAuth2 login to the app"
    │
    ▼
orchestrator (Opus)
  - Analyzes the codebase
  - Decomposes: auth middleware + routes + frontend + tests + docs
  - Creates 5 tasks
  - Delegates: builder (middleware + routes), builder (frontend), verifier (tests)
    │
    ├── builder (Sonnet) → implements auth middleware
    ├── builder (Sonnet) → implements frontend OAuth flow
    └── verifier (Sonnet) → runs tests, adds coverage
    │
    ▼
orchestrator collects results → reports to user
```

No agent steps outside its lane. Builder doesn't write tests (verifier does). Verifier doesn't touch implementation (builder does). Orchestrator doesn't write code.

## When to Skip Specialization

For simple 1-2 file changes, agent dispatch overhead isn't worth it. Use specialized agents when:
- The task spans 3+ files or concerns
- You need parallel execution across independent workstreams
- You want explicit separation between "planning" and "implementing"
- Security review is needed (always use the security-reviewer agent — it has an Opus model and a security-specific system prompt)

## Implementation

See: [`agents/`](../agents/) directory — each agent is a standalone `.md` file dropped into `~/.claude/agents/`.
