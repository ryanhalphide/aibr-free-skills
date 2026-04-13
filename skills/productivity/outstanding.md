---
name: outstanding
description: "Comprehensive inventory of ALL unfinished business across ALL projects — plans, git, blockers, testing, deployment, cleanup. Use when the user says '/outstanding', 'what's outstanding', 'show everything outstanding', 'full inventory', 'open items', 'what needs doing', 'unfinished business', 'what's left', or wants a strategic overview of all remaining work. Also trigger for '/outstanding [project-name]' to filter to one project."
---

# Outstanding — Strategic Work Inventory

Surface everything that's unfinished, uncompleted, blocked, or forgotten across all projects. This is a **read-only report** — it inventories work, it doesn't execute it.

**How this differs from other skills:**
- `/next` = what to do RIGHT NOW in this session (tactical, single-project)
- `/outstanding` = complete inventory of ALL unfinished business (strategic, read-only)

## Arguments

| Argument | Behavior |
|----------|----------|
| (none) | Full report across all projects |
| `{project-name}` | Single project, expanded detail |
| `--compact` | Summary counts only, 1 line per project |
| `--blocked` | Only blocked/waiting items |
| `--git` | Only git status across all repos |

## Process

### Step 1: Gather

Collect data from available sources:

```bash
# Session state
cat ~/.claude/.current-work-session.json 2>/dev/null

# Recent plan files
ls -t *.md .planning/*.md ~/.claude/plans/*.md 2>/dev/null | head -10

# Git status across repos
for repo in ~/Code/*/; do
  [ -d "$repo/.git" ] && echo "=== $repo ===" && git -C "$repo" status --short && git -C "$repo" log --oneline -1
done 2>/dev/null
```

Structured sources to read:
1. Session state — `next_action`, `completed_this_session`
2. Plan files (10 most recent) — unchecked items, blocked items
3. `.planning/` directories — roadmap progress, STATE.md next steps
4. Git status (all repos) — dirty files, unpushed commits, days since last commit

### Step 2: Enrich

For projects with recent activity or active blockers, read these additional files:
- **Project CLAUDE.md** — look for "TODO", "Known Issues", "Next Steps" sections
- **`.planning/STATE.md`** — deferred issues, pending architectural decisions

Only enrich for active projects. Skip paused/archived projects unless specifically requested.

### Step 3: Categorize

Tag every outstanding item with one of these SDLC categories:

| Category | What goes here |
|----------|----------------|
| **Planning** | Roadmap phases not yet planned, architectural decisions pending |
| **Implementation** | Code to write, features to build, unchecked plan items |
| **Testing** | Tests to write or run, unverified features |
| **Verification** | Deploy verification, health checks, manual QA |
| **Deployment** | Uncommitted code, unpushed commits, pending deploys |
| **Cleanup/Debt** | TODO/FIXME in code, stale configs, dead branches |
| **Documentation** | Docs to write or update, README gaps |
| **Blocked/Waiting** | Items blocked on external dependencies, credentials, or decisions |

### Step 4: Prioritize

Sort items into 4 priority tiers:

**P0 Critical** — Active blockers on important work. Hard deadlines. Production-down items.

**P1 High** — Work currently in-progress. Session next_action items. Uncommitted work on active branches.

**P2 Medium** — Quick wins, next steps for active projects, unchecked plan items.

**P3 Low** — Paused project items, enrichment ideas, dormant repos.

### Step 5: Render

```
══════════════════════════════════════════════════════════════
  /outstanding                          {date} {time}
══════════════════════════════════════════════════════════════

  SUMMARY: {N} items across {M} active projects
  P0: {n} | P1: {n} | P2: {n} | P3: {n}

  P0 CRITICAL
  [{project}] {description}
              Blocker since: {date} ({days}d)
              Impact: {what's blocked}
              Action: {who/what is needed}

  P1 HIGH
  [{project}] {description}
              Source: {where this came from}
              Category: {SDLC category}

  P2 MEDIUM
  (grouped by project, max 5 per project in all-projects mode)
  [{project}] {item}
              Category: {category}

  P3 LOW
  (collapsed summary — just counts per project)
  [{project}] {count} items ({categories involved})

  GIT STATUS
  (only repos with dirty or unpushed changes)
  {repo:<24}  {branch:<12}  {dirty} dirty  {unpushed} unpushed  {days}d ago

  DORMANT (>14d since commit)
  {repo} {days}d | {repo} {days}d | ...

══════════════════════════════════════════════════════════════
  /outstanding {project}  — drill into one project
  /outstanding --compact  — summary counts only
  /outstanding --blocked  — only blocked items
  /outstanding --git      — only git status
══════════════════════════════════════════════════════════════
```

**For `--compact` mode**, show only:
```
  SUMMARY: {N} items | P0: {n} P1: {n} P2: {n} P3: {n}
  {project:<16} {status:<8} P0:{n} P1:{n} P2:{n} P3:{n}  Last: {days}d ago
```

**For `--blocked` mode**, show only P0 + Blocked/Waiting items with full detail.

**For `--git` mode**, show only the GIT STATUS and DORMANT sections.

**For single-project mode** (`/outstanding [project-name]`), expand all items for that project with full detail — no caps per section. Include the project's current phase, git status, and any plan file outstanding items.

## Important Notes

- This skill reads from multiple sources that may be stale. Cross-reference git commit dates with state file modification dates. If a state file is >14 days older than the latest git commit, note it may be outdated.
- The session state `next_action` field represents what was explicitly noted as next — always include it as P1.
- Dormant repos (>14 days) are informational, not necessarily outstanding work. They go in P3 unless they have dirty/unpushed changes (then P2).
- This is read-only. Do not apply fixes, commit changes, or execute actions. Surface findings, let the user decide what to act on.
