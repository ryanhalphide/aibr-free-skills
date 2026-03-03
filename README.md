# AIBR Free Claude Code Skills

**By AI Boost Realization**

Three production-grade Claude Code skills, free forever. Drop them into your `.claude/commands/` directory and invoke them with a slash command. No API keys, no setup, no paywalls.

These are real tools from our internal workflow — not demos.

---

## Skills in This Pack

### `/quick-debug` — Hypothesis-First Bug Diagnosis

Stop thrashing through random fixes. This skill structures your debugging into a single, disciplined pass:

1. Gathers the full signal set (error, stack trace, recent commits, diff)
2. Generates 3 ranked hypotheses with explicit verification steps
3. Verifies the most likely cause first — never guesses
4. Applies a targeted fix and confirms the regression is closed
5. Runs a 30-second post-mortem to prevent the same bug from recurring

**Best for:** Runtime errors, test failures, silent regressions, "it was working yesterday" situations.

File: [`quick-debug.md`](./quick-debug.md)

---

### `/smart-commit` — Diff-Aware Commit Generator

Writes a precise conventional commit message based on what actually changed — not what you remember changing. Also handles pre-commit hook failures without data loss.

1. Assesses the working tree and categorizes every changed file
2. Stages only files that belong in this commit (skips unrelated changes and flags secrets)
3. Reads the staged diff and derives a conventional commit message
4. Runs pre-commit hooks — if they fail, fixes the issues and commits cleanly
5. Verifies the final commit contains exactly what was intended

**Best for:** End-of-feature commits, keeping a clean git history, teams that enforce conventional commits.

File: [`smart-commit.md`](./smart-commit.md)

---

### `/project-scanner` — Project Health Auditor

A full five-point health check that surfaces the issues quietly compounding into technical debt. Runs in under a minute, generates a scored, prioritized report.

**Scans:**
1. **Env Var Audit** — finds references in code with no definition, and secrets that may be committed
2. **Dependency Health** — surfaces major-version-behind packages and unused direct dependencies
3. **Security Vulnerabilities** — runs `npm audit` and checks for hardcoded secrets patterns
4. **Unused Exports** — identifies dead code that can be safely deleted
5. **Code Health Signals** — counts TODO debt, stray `console.log` calls, and TypeScript `any` usage

Output is a prioritized report scored out of 100. Nothing is auto-fixed — you stay in control.

**Best for:** Onboarding onto an unfamiliar codebase, pre-release checks, quarterly maintenance.

File: [`project-scanner.md`](./project-scanner.md)

---

## Installation

Claude Code skills live in your `.claude/commands/` directory:

```bash
# Copy all three skills
cp quick-debug.md smart-commit.md project-scanner.md ~/.claude/commands/

# Or symlink from this repo (stays updated with git pull)
ln -s "$(pwd)/quick-debug.md" ~/.claude/commands/quick-debug.md
ln -s "$(pwd)/smart-commit.md" ~/.claude/commands/smart-commit.md
ln -s "$(pwd)/project-scanner.md" ~/.claude/commands/project-scanner.md
```

Then invoke in any Claude Code session:

```
/quick-debug TypeError: Cannot read properties of undefined
/smart-commit
/project-scanner
/project-scanner ~/Desktop/some-other-project
```

---

## The Full AIBR Agent Framework

These three skills are drawn from a 50+ skill suite that covers the entire development lifecycle — from planning and scaffolding through deployment, monitoring, and team handoffs.

The premium pack includes skills for:

- **Planning** — scope decomposition, risk analysis, architecture review
- **Code Generation** — component scaffolding, API route generation, migration writing
- **Review** — automated PR review with severity ratings, security audit, performance analysis
- **Testing** — test case generation, coverage gap analysis, snapshot management
- **Deployment** — pre-deploy checklist, rollback playbooks, environment promotion
- **Documentation** — auto-docstring generation, changelog drafting, ADR writing
- **Team Workflows** — standup prep, sprint retrospective, onboarding guide generation
- **Debugging** — advanced versions of quick-debug with LLM-assisted log analysis

**Get the full suite:** [https://aiboosted4.gumroad.com/l/claude-code-power-user](https://aiboosted4.gumroad.com/l/claude-code-power-user)

---

## About AIBR

AI Boost Realization builds practical AI tooling for developers who want to move faster without sacrificing code quality. We ship tools we use ourselves, then release the best parts.

- GitHub: [github.com/aiboostreal](https://github.com/aiboostreal)
- Gumroad: [aiboosted4.gumroad.com](https://aiboosted4.gumroad.com)

---

*Free to use, share, and fork. Attribution appreciated but not required.*
