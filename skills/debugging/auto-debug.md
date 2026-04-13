---
name: auto-debug
description: Autonomous self-healing debug loop — runs tests, fixes failures, and iterates until green or budget exhausted
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
user_invocable: true
argument-hint: "[optional: test command override, e.g. 'pytest tests/' or 'npm test']"
---

# Auto Debug — Self-Healing Debug Loop

Act as an autonomous debugging agent. Follow this strict loop until all tests pass or every failure has been attempted with 3 strategies.

## Setup

1. Detect the test command for this project (check package.json scripts, Makefile, pytest.ini, etc.)
2. Create a checklist to track each bug, approaches tried, and status

## Loop (per failure)

1. **Run** the full test suite and capture ALL output
2. **Parse** every failure — extract file, line number, error message, and expected vs actual
3. **For each failure:**
   a. Read the relevant source files around the failure point
   b. Identify the root cause (not just the symptom)
   c. Apply the minimal fix
   d. Re-run the specific failing test to verify
4. **If a fix doesn't resolve the failure after 2 attempts:**
   - Revert the fix completely
   - Try a fundamentally different approach (not a variation of the same idea)
5. **If 3 distinct strategies fail for one bug:**
   - Mark it as "needs human review" in the checklist
   - Move to the next failure

## Completion

Continue until ALL tests pass or every failure has been attempted with 3 strategies.

Run the full test suite one final time to confirm no regressions.

Produce a summary report:
- What was fixed (with brief explanation of each root cause)
- What remains unfixed and why
- Any architectural concerns discovered during debugging
- Total test runs performed

## Rules

- Never skip a failing test or mark it as expected-to-fail
- Never modify test assertions to match buggy behavior
- If fixing one bug breaks another, treat it as a regression and fix both
- Track progress throughout — mark items done as you go
- After 2 failed fix attempts on the same bug, STOP and try a completely different approach
- Do NOT shotgun-fix — understand WHY each attempt failed before trying the next one
