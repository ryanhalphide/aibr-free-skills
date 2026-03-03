---
name: quick-debug
description: Hypothesis-first bug diagnosis — ranks 3 root causes by likelihood, verifies the winner, and applies a targeted fix without guess-and-check iteration
argument-hint: "[optional: paste error message or describe symptom]"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
user_invocable: true
---

# Quick Debug

Stop guessing. Diagnose bugs in a single structured pass using a ranked-hypothesis approach.

## When to Use

- Unexpected runtime errors or exceptions
- Tests passing locally but failing in CI
- Silent failures where nothing obviously broke
- Behavior changed after a recent commit

## Process

### Step 1 — Gather Context

Before forming any hypothesis, collect the signals:

1. Read the full error message and stack trace. Note the exact file and line number.
2. Run `git log --oneline -10` to see recent commits that could have introduced the regression.
3. Run `git diff HEAD~1` (or against the last known-good commit) to see what changed.
4. If a test is failing, read the test file and the implementation it tests side by side.
5. Grep for the failing symbol/function across the codebase to understand all call sites:
   ```bash
   grep -rn "functionName" src/
   ```

### Step 2 — Form 3 Hypotheses

Based on collected evidence, generate exactly 3 hypotheses ranked by likelihood. Format:

```
Hypothesis 1 (most likely — ~60%): [specific cause]
  Evidence: [what signals support this]
  Verify: [exact command or file to check]

Hypothesis 2 (~30%): [specific cause]
  Evidence: [what signals support this]
  Verify: [exact command or file to check]

Hypothesis 3 (~10%): [specific cause]
  Evidence: [what signals support this]
  Verify: [exact command or file to check]
```

**Rules for hypotheses:**
- Each must be specific enough to verify in one step
- Must be mutually exclusive where possible
- Do not include "might be a bug somewhere" — that is not a hypothesis

### Step 3 — Verify Most Likely First

Execute the verification command for Hypothesis 1. Report the result. If confirmed:
- Apply the targeted fix
- Re-run the failing test or command to confirm resolution
- Move on

If Hypothesis 1 is ruled out, verify Hypothesis 2. Do NOT start fixing until a hypothesis is confirmed.

### Step 4 — Apply the Fix

Once the root cause is confirmed:
1. Make the minimal change that addresses the confirmed root cause
2. Do not refactor unrelated code in the same edit
3. Run the full test suite or build: `npm run test` / `npm run build` / appropriate command
4. Confirm the fix resolves the original symptom without introducing new failures

### Step 5 — Post-Mortem (30 seconds)

After fixing, note:
- What was the actual root cause?
- What made it hard to spot initially?
- Is there a lint rule, type check, or test that would have caught this earlier?

If the answer to the last question is yes, add it. Compounding knowledge prevents repeat bugs.

## If All 3 Hypotheses Fail

Stop. Do not iterate into a fourth guess. Instead:
1. Re-read the error message literally — what does it actually say vs. what you assumed?
2. Check if the issue is environmental (wrong Node version, missing env var, stale cache)
3. Reproduce in isolation: create the smallest possible repro case
4. Present findings and ask the user for additional context before proceeding

## Example Output

```
Diagnosing: "TypeError: Cannot read properties of undefined (reading 'id')"

Hypothesis 1 (65%): `user` object is undefined because the async DB call resolved after render
  Evidence: Error fires on component mount, user comes from async hook
  Verify: Check if useUser() returns undefined on first render

Hypothesis 2 (25%): API response shape changed — `user` field was renamed `account`
  Evidence: Last commit touched the API response transformer
  Verify: console.log(rawResponse) in the fetch call

Hypothesis 3 (10%): Stale type definitions — runtime shape differs from TypeScript types
  Evidence: ts build passes but runtime fails
  Verify: Check actual API response against the TypeScript interface

Verifying H1...
```

---

*Part of the AIBR Agent Framework. Get the full 50+ skill suite at https://aiboosted4.gumroad.com/l/claude-code-power-user*
