# Agent Specialization System

A set of 12 Claude Code agents, each scoped to a single responsibility. Drop them into `~/.claude/agents/` and Claude Code will pick them up automatically.

## Why narrow roles beat general agents

A general-purpose agent accumulates context, second-guesses its own scope, and drifts. A specialist agent knows exactly what it can and cannot touch. The benefits compound:

- **Fewer errors.** An agent that cannot write to `.env` files will never accidentally overwrite a live credential.
- **Parallelism.** Independent specialists can run concurrently without file-ownership collisions.
- **Cost control.** Haiku for search. Sonnet for implementation. Opus for architecture. You pay for what the task actually needs.
- **Auditable handoffs.** Each agent returns a typed result (PASS/FAIL, APPROVED/CHANGES_REQUESTED, DEPLOY_SUCCESS). The next agent in the chain has a clear signal, not a blob of prose.

## Agent hierarchy

```
Opus (deep reasoning, expensive)
  orchestrator  — decomposes work, delegates, never codes
  planner       — writes saved-plan.md, creates tasks
  security-reviewer — finds real vulns, not nits
  refactorer    — cross-file structural changes

Sonnet (implementation, balanced)
  builder       — writes production code
  verifier      — tests, typecheck, lint
  deployer      — Railway / Vercel / Fly.io
  reviewer      — code review, suggests only
  migrator      — DB schema migrations

Haiku (fast, cheap, read-heavy)
  explorer      — read-only codebase mapping
  scribe        — markdown docs only
  dependency-updater — audit + batch-update deps
```

## Agent reference table

| Agent | Model | Role | Key Tools | Cannot Do |
|---|---|---|---|---|
| orchestrator | Opus | Decomposes tasks, delegates to specialists | Agent, TaskCreate, TaskUpdate | Write, Edit, Bash (no direct code or shell) |
| planner | Opus | Writes implementation plans to saved-plan.md | Read, Glob, Grep, Write, Agent | Edit, Bash, deploy anything |
| builder | Sonnet | Implements features, endpoints, components | Read, Write, Edit, Bash, LSP | Write tests, docs, deploy configs, .env |
| verifier | Sonnet | Runs tests, typecheck, lint; writes test files | Read, Write, Edit, Bash, LSP | Modify implementation files, deploy |
| deployer | Sonnet | Deploys to Railway/Vercel/Fly.io | Read, Bash, WebFetch | Write, Edit any source file |
| reviewer | Sonnet | Code review (read-only, suggests only) | Read, Glob, Grep, Bash, LSP | Write or Edit anything |
| security-reviewer | Opus | Credential leaks, injection, auth gaps | Read, Glob, Grep, Bash, LSP | WebFetch, WebSearch, task tracking |
| migrator | Sonnet | DB schema migrations with rollback | Read, Write, Edit, Bash, LSP | WebFetch, task tracking |
| refactorer | Opus | Cross-file renames, extract/move, import updates | Read, Write, Edit, Bash, LSP | WebFetch, task tracking |
| explorer | Haiku | Read-only architecture mapping | Read, Glob, Grep, LSP | Write, Edit, Bash, any modification |
| scribe | Haiku | Markdown documentation only | Read, Write, Edit, Glob, Grep, WebFetch | Bash, source code edits, .env |
| dependency-updater | Haiku | Audits and batch-updates dependencies | Read, Write, Edit, Bash, WebSearch, WebFetch | LSP, task tracking |

## Installation

Copy any agent file you want to use into `~/.claude/agents/`:

```bash
cp agents/builder.md ~/.claude/agents/
cp agents/verifier.md ~/.claude/agents/
# etc.
```

Claude Code picks up agents from that directory automatically. No restart needed.

To use the full system, copy all 12 files.

## How to invoke agents in Claude Code

The `Agent` tool (available in Claude Code) spawns a named agent as a subagent:

```
Agent(builder, "Add a POST /users endpoint to src/routes/users.ts following the existing pattern in src/routes/posts.ts")
```

You can spawn multiple independent agents in a single message for parallel execution:

```
Agent(builder, "Implement the cache layer in src/lib/cache.ts")
Agent(scribe, "Update README with cache usage examples")
```

Agents report back to the calling context when done. Sequential work is handled by chaining:

```
result = Agent(builder, "...")
Agent(verifier, f"Verify the changes from builder: {result}")
```

## Worked example: orchestrator to builder to verifier

**Task:** Add email verification to the user registration flow.

**Step 1 — Orchestrator plans**

The orchestrator spawns the planner, which maps the codebase (via explorer) and writes a plan to `~/.claude/shared-state/saved-plan.md`:

```
Plan: Email Verification for User Registration

Steps:
1. src/lib/email.ts — add sendVerificationEmail(user) using existing nodemailer setup
2. src/routes/auth.ts:47 — after user insert, call sendVerificationEmail, set verified=false
3. src/routes/auth.ts — add GET /verify-email?token=... route
4. drizzle/schema.ts — add verified boolean + verificationToken string to users table

Verification:
- POST /register returns 201, email sent (check logs)
- GET /verify-email?token=valid sets verified=true
- GET /verify-email?token=invalid returns 400
```

**Step 2 — Orchestrator dispatches builder**

The orchestrator assigns files explicitly to prevent collisions:

```
Agent(builder, "Implement email verification per saved-plan.md.
Files assigned to you: src/lib/email.ts, src/routes/auth.ts, drizzle/schema.ts.
Do not touch test files.")
```

Builder returns: "3 files changed. tsc --noEmit clean. Migration generated at drizzle/0012_add_email_verification.sql."

**Step 3 — Orchestrator dispatches verifier**

```
Agent(verifier, "Verify the email verification implementation.
Builder changed: src/lib/email.ts, src/routes/auth.ts, drizzle/schema.ts.
Run full test suite and typecheck. Add tests if coverage is missing for the new routes.")
```

Verifier returns: "PASS. 3 new test cases added. 47/47 tests passing. tsc clean."

**Step 4 — Orchestrator dispatches reviewer**

```
Agent(reviewer, "Review the email verification diff for security and correctness.
Focus on token generation strength, expiry handling, and route auth.")
```

Reviewer returns: "APPROVED_WITH_COMMENTS. [MEDIUM] src/routes/auth.ts:89 -- token uses Math.random(), should use crypto.randomBytes(32)."

**Step 5 — Back to builder for the fix**

```
Agent(builder, "Fix: replace Math.random() token generation with crypto.randomBytes(32).toString('hex') at src/routes/auth.ts:89")
```

**Step 6 — Deploy**

```
Agent(deployer, "Deploy [your-project] backend to Railway. Verifier PASS confirmed. Run migration before deploy.")
```

## Customizing for your project

Each agent file has a `context:` block in the frontmatter. Update these with your actual service names, ORM, and deployment targets before copying to `~/.claude/agents/`. The behavioral instructions (the body of each file) are ready to use as-is.

The `security-reviewer` context block lists common secret patterns. Add your own API key prefixes there so the agent knows what to scan for.

The `deployer` context block has placeholder service names -- replace them with your actual Railway services, Vercel projects, and Fly apps.
