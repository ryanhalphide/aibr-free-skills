---
name: project-scanner
description: Scans a project for missing env vars, outdated dependencies, security vulnerabilities, and unused exports — then generates a prioritized health report
argument-hint: "[optional: path to project root, defaults to current directory]"
allowed-tools: ["Read", "Bash", "Grep", "Glob"]
user_invocable: true
---

# Project Scanner

A full-project health check in one command. Surfaces the issues that quietly compound into technical debt.

## When to Use

- Before starting a new feature on an unfamiliar codebase
- After inheriting a project or joining a team
- As a periodic maintenance check (weekly or before releases)
- When something feels off but you cannot pinpoint why

## Scans Performed

### Scan 1 — Environment Variable Audit

Find all env var references in the codebase:
```bash
grep -rn "process\.env\." src/ --include="*.ts" --include="*.js" --include="*.tsx"
```

Compare against the variables actually defined:
- Read `.env`, `.env.local`, `.env.example`, `.env.production` if they exist
- List any `process.env.X` references in code that have no corresponding entry in any `.env*` file
- Flag `.env` files that are committed to git (check `.gitignore`)

Output format:
```
ENV AUDIT
  Missing (referenced in code, not defined): STRIPE_SECRET_KEY, DATABASE_URL
  Defined but never used: LEGACY_API_URL
  Security risk: .env is NOT in .gitignore
```

### Scan 2 — Dependency Health

Read `package.json` (or `pyproject.toml` / `Cargo.toml` etc.) and check:

```bash
npm outdated --json 2>/dev/null || true
```

Categorize:
- **Critical outdated**: major version behind (e.g., React 17 when 19 is current)
- **Minor outdated**: minor/patch behind — typically safe to upgrade
- **Unused direct dependencies**: packages in `dependencies` not imported anywhere in `src/`

For unused dependency detection, grep for each package name across source files:
```bash
grep -rn "from 'packagename'" src/ | head -1
```

Output format:
```
DEPENDENCY HEALTH
  Critical (major version behind): next@13 (current: 15), typescript@4 (current: 5)
  Unused direct dependencies: lodash, moment (consider removing)
  Audit: run `npm audit` for vulnerability details
```

### Scan 3 — Security Vulnerabilities

Run the built-in audit tool if available:
```bash
npm audit --json 2>/dev/null | head -100 || echo "npm audit not available"
```

Summarize:
- Count of critical, high, moderate, low severity issues
- Name the top 3 most severe vulnerabilities with the affected package
- Note whether `npm audit fix` can resolve them automatically

Also check for hardcoded secrets patterns:
```bash
grep -rn --include="*.ts" --include="*.js" --include="*.tsx" \
  -E "(api_key|apikey|secret|password|token)\s*=\s*['\"][a-zA-Z0-9+/]{16,}" src/ 2>/dev/null | head -10
```

### Scan 4 — Unused Exports

Find exports that are never imported within the project:

```bash
# Find all named exports
grep -rn "^export (const|function|class|type|interface)" src/ --include="*.ts" --include="*.tsx" | head -50
```

For each export found, check if it appears as an import anywhere else. Flag exports that:
- Are not imported in any other file within `src/`
- Are not entry points (not referenced from `index.ts` or a route file)

```
UNUSED EXPORTS
  src/utils/legacyFormatter.ts: formatLegacyDate, parseLegacyId
  src/components/OldModal.tsx: OldModal (entire file may be dead code)
```

### Scan 5 — Code Health Signals

Quick structural signals that indicate deeper issues:

```bash
# TODO/FIXME debt count
grep -rn "TODO\|FIXME\|HACK\|XXX" src/ --include="*.ts" --include="*.tsx" | wc -l

# Console.log left in production code
grep -rn "console\.log" src/ --include="*.ts" --include="*.tsx" | grep -v ".test." | wc -l

# TypeScript 'any' usage
grep -rn ": any\b\|as any\b" src/ --include="*.ts" --include="*.tsx" | wc -l
```

## Health Report Output

Produce a final prioritized report in this format:

```
PROJECT HEALTH REPORT — [project name] — [date]
================================================

CRITICAL (fix before next deploy)
  [1] Missing env vars: STRIPE_SECRET_KEY, DATABASE_URL
      These will cause runtime crashes in production.

  [2] 3 high-severity npm vulnerabilities
      Run: npm audit fix

HIGH (fix this sprint)
  [3] .env not in .gitignore — secrets may already be in git history
      Run: git rm --cached .env && echo ".env" >> .gitignore

  [4] next@13 is 2 major versions behind (current: 15)
      Breaking changes exist — plan a dedicated upgrade.

MEDIUM (schedule for cleanup)
  [5] 47 TODO/FIXME comments accumulating
  [6] 23 console.log statements in production code paths
  [7] 2 likely-dead files: OldModal.tsx, legacyFormatter.ts

LOW (nice to have)
  [8] 3 unused direct dependencies (lodash, moment, uuid)
      Removing reduces bundle size and attack surface.
  [9] 31 uses of 'any' type — consider tightening over time

SCORE: [X/100]
  (100 = no issues found across all 5 scans)
```

## Score Calculation

- Each critical issue: -20 points
- Each high issue: -10 points
- Each medium issue: -3 points
- Each low issue: -1 point
- Floor at 0

## After the Report

Do not auto-fix anything. Present the report and let the user decide which items to address. For any item the user selects, use the appropriate skill to resolve it (e.g., `quick-debug` for errors, `smart-commit` after fixes).

---

*Part of the AIBR Agent Framework. Get the full 50+ skill suite at https://aiboosted4.gumroad.com/l/claude-code-power-user*
