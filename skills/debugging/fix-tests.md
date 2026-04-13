---
name: fix-tests
description: Autonomous bug-fix loop against test suites — runs tests, groups failures, dispatches parallel fix agents, iterates up to 5 rounds, surfaces PR-ready diff
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent"]
user_invocable: true
argument-hint: "[test-command] [--max-iter N]"
---

# Fix Tests — Autonomous Bug-Fix Loop

## This is a RIGID skill — follow every step exactly.

Runs the test suite, groups failures by domain, dispatches parallel fix agents, and iterates until green or 5 rounds.

---

## Step 1: Parse Arguments

- `[test-command]`: override the default test command (e.g. `pytest tests/`, `npm test`, `cargo test`)
- `--max-iter N`: override iteration limit (default: 5)

If no test command given, auto-detect:
```bash
[ -f pytest.ini ] || [ -f pyproject.toml ] && echo "python -m pytest -x --tb=short"
[ -f package.json ] && grep -q '"test"' package.json && echo "npm test"
[ -f Cargo.toml ] && echo "cargo test"
```

---

## Step 2: Run Full Test Suite

```bash
cd /current/project/dir && [TEST_COMMAND] 2>&1 | tee /tmp/test-output.txt
```

Capture: exit code, number of failures, full output.

If exit code 0: output "All tests passing. No work needed." and stop.

---

## Step 3: Parse Failures

From `/tmp/test-output.txt`, extract:
- Each failing test name
- The error message / traceback
- The file path for each failure

Group by domain using this heuristic:
- Same file → same group
- Same module/package directory → same group
- Files with no shared imports (check with grep) → separate groups

Output a table:
```
GROUP 1: [file/module]
  - [test name]: [one-line error summary]
  - [test name]: [one-line error summary]

GROUP 2: [file/module]
  - [test name]: [one-line error summary]
```

---

## Step 4: Dispatch Fix Agents (or Fix Inline)

**If 1-2 failures**: fix inline. Read the failing test + implementation, diagnose, fix.

**If 3+ failures in independent groups**: dispatch one agent per group in parallel (single message).

Agent prompt template:
```
You are a bug-fix agent. Fix the failing tests described below.

**Failing tests in [FILE/MODULE]:**
[paste test names + full error messages]

**Context:**
[paste the relevant implementation file(s) content]
[paste the relevant test file content]

**Constraints:**
- Fix the IMPLEMENTATION, not the test expectations (unless the test is clearly wrong)
- Do NOT edit files outside [FILE/MODULE]'s package boundary
- Do NOT modify .env, shared config, or other agents' scope
- Use the simplest fix that makes the test pass
- If the test expectation is wrong (tests something that should have changed), explain why and fix the test

**Return:**
1. Root cause (one sentence)
2. What you changed and why
3. "stuck: [reason]" if you cannot fix it after 3 attempts
```

---

## Step 5: Integrate and Re-Run

After all agents return:
1. Read each agent's summary
2. Check for file conflicts (two agents edited the same file?) — resolve manually if so
3. Re-run full test suite

---

## Step 6: Iterate (max 5 rounds)

Track: `iteration = 1`

On each re-run:
- If green: go to Step 7
- If still failing: increment iteration
- If same tests still failing after same fix: **change approach** — do not repeat identical fix
- If `iteration >= 5`: go to Step 8 (failure report)

**Approach change rule**: If the same test fails after 2 rounds with the same fix strategy:
1. Stop trying that approach
2. State: "Previous approach failed. Trying alternative: [hypothesis]"
3. Try a completely different root cause hypothesis

---

## Step 7: Success Report

```
FIX-TESTS: ALL GREEN

Iterations: N
Tests fixed: X
Files modified: [list]

Summary of changes:
- [file]: [what was fixed]
- [file]: [what was fixed]

PR-ready diff: run `git diff` to review
```

---

## Step 8: Failure Report (after 5 iterations)

```
FIX-TESTS: STUCK after 5 iterations

Still failing:
- [test name]: [error]

Approaches tried:
1. [approach 1] — result: [what happened]
2. [approach 2] — result: [what happened]

Recommended next step:
[specific hypothesis about root cause that requires human review]
[OR: specific file/function to investigate]
```

Do NOT keep iterating. Surface to human for review.

---

## Parallel Fix Agent Isolation Rules

When dispatching fix agents:
- Each agent gets only the files it needs
- No agent modifies shared config or `.env`
- Parent merges results after all agents return
- Two agents must never edit the same file — resolve conflicts in the parent
