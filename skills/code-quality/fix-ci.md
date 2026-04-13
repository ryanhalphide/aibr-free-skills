---
name: fix-ci
description: Diagnose and fix CI/CD failures by reading pipeline logs, identifying root cause, and applying targeted fixes
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
user_invocable: true
argument-hint: "[optional: CI run URL or run ID to inspect]"
---

# Fix CI

Diagnose and fix CI/CD pipeline failures. Reads the actual failure logs, forms hypotheses about root cause, verifies locally, and applies a targeted fix — no shotgun patching.

## When to Use

- A GitHub Actions run just failed
- CI was green locally but red on push
- A pipeline that was working started failing after a dependency update
- You need to understand what CI is actually checking before fixing it

## Process

### Step 1 — Fetch the Failure

Get the CI failure output:

```bash
# List recent runs
gh run list --limit 5

# View the failed run (use the run ID from above)
gh run view --log-failed

# Or for a specific run
gh run view [RUN_ID] --log-failed
```

Read the full failure output. Note:
- Which job failed (lint, test, build, deploy?)
- The exact error message and line
- Which step within the job failed
- The environment (OS, Node version, Python version, etc.)

### Step 2 — Form 3 Hypotheses

Based on the failure output, generate exactly 3 hypotheses ranked by likelihood:

```
Hypothesis 1 (most likely — ~X%): [specific cause]
  Evidence: [what in the CI log points here]
  Verify: [exact command to reproduce locally]

Hypothesis 2 (~Y%): [specific cause]
  Evidence: [signals]
  Verify: [command]

Hypothesis 3 (~Z%): [specific cause]
  Evidence: [signals]
  Verify: [command]
```

**Common CI failure patterns to consider:**

| Pattern | Signal in logs |
|---------|----------------|
| Lockfile drift | "npm ci" fails, "package-lock.json out of sync" |
| Node/Python version mismatch | "SyntaxError" on valid code, unexpected API missing |
| Missing env var | "undefined" reference to env var, auth failure |
| Test flakiness | Failure on timing-sensitive test, passes on retry |
| Import/module not found | "Cannot find module", "ModuleNotFoundError" |
| Type error (TS strict) | Passes locally with loose settings, fails with strict |
| Build artifact missing | Deploy step fails because build step output not found |
| Cache invalidation | Stale cached node_modules with wrong versions |

### Step 3 — Verify Locally

Reproduce the failure locally before writing any fix:

```bash
# Match CI environment as closely as possible
node --version  # compare to CI node version in workflow file
cat .nvmrc 2>/dev/null || cat .node-version 2>/dev/null

# For npm ci failures
rm -rf node_modules && npm ci

# For test failures — run the exact failing test
npm test -- --testPathPattern="[failing test file]"

# For TypeScript failures
npx tsc --noEmit

# For lint failures
npm run lint
```

Read the CI workflow file to understand exactly what commands it runs:
```bash
cat .github/workflows/*.yml
```

### Step 4 — Apply the Fix

Once the root cause is confirmed, apply the minimal targeted fix:

**Lockfile drift:**
```bash
npm install  # regenerates package-lock.json
git add package-lock.json
```

**Node version mismatch:**
- Update `.nvmrc` or `.node-version` to match what CI specifies
- Or update the CI workflow to match the version in use locally

**Missing env var:**
- Add to GitHub repository secrets (Settings > Secrets)
- Reference in the workflow file under `env:` or `with:`
- Add a placeholder to `.env.example` so future devs know it's needed

**TypeScript strict failure:**
```bash
# Run with same flags as CI
npx tsc --noEmit --strict
# Fix each error, do NOT relax tsconfig
```

**Flaky test:**
- Add retry logic only if the test genuinely covers non-deterministic behavior
- More often: fix the underlying timing issue (await missing, race condition)

### Step 5 — Verify Locally Before Push

Run the same commands CI will run, in order:

```bash
# Install clean (no cache)
npm ci

# Type check
npx tsc --noEmit

# Lint
npm run lint

# Tests
npm test

# Build
npm run build
```

All must pass before committing the fix.

### Step 6 — Commit and Push

```bash
git add [changed files]
git commit -m "fix(ci): [description of what was fixed and why]"
git push
```

### Step 7 — Confirm CI Green

After pushing, watch the new run:

```bash
gh run list --limit 3
gh run watch  # streams live output
```

Do NOT declare done until CI reports green on the new commit.

## If All 3 Hypotheses Fail

Stop. Do not start randomly changing things.

1. Re-read the CI log literally — what does it say on the LAST line before the failure?
2. Check if the failure is in a dependency you didn't write (look at the stack trace depth)
3. Compare the CI environment to local exactly: OS, Node version, npm version, env vars
4. Search the dependency's GitHub issues for the exact error message
5. Present findings and ask for help before proceeding

## Workflow File Reference

The CI workflow file controls everything. Always read it first:

```bash
# List all workflow files
ls .github/workflows/

# Read the relevant one
cat .github/workflows/[name].yml
```

Key things to check:
- `node-version` or `python-version` — must match local
- `cache:` settings — stale caches cause phantom failures
- `env:` blocks — are all required env vars set?
- Step order — does the build step happen before the deploy step?
