---
name: smart-commit
description: Analyzes your git diff, auto-stages relevant files, writes a precise commit message, and handles pre-commit hook failures gracefully
argument-hint: "[optional: scope or context hint, e.g. 'auth refactor' or 'fixes #42']"
allowed-tools: ["Bash", "Read", "Write"]
user_invocable: true
---

# Smart Commit

Commit the right files with the right message — without writing boilerplate or hunting for what changed.

## When to Use

- After completing a feature, fix, or refactor
- When you have multiple changed files and need to stage only the relevant ones
- When you want a consistent, meaningful commit message without thinking about format
- When a pre-commit hook fails and you need to recover cleanly

## Process

### Step 1 — Assess the Working Tree

Run these commands to understand the current state:

```bash
git status
git diff --stat
git diff HEAD
```

Report a summary:
- How many files changed
- Whether there are untracked files that should be included
- Whether there are changes that clearly belong to a different concern (should NOT be in this commit)

### Step 2 — Identify What Belongs in This Commit

Review the diff and categorize every changed file into one of three buckets:

| Bucket | Description | Action |
|--------|-------------|--------|
| **Include** | Directly related to the work just done | Stage it |
| **Exclude — save for later** | Unrelated change mixed in (e.g., a typo fix in an unrelated file) | Leave unstaged |
| **Exclude — never commit** | Secrets, build artifacts, editor configs, `.env` files | Warn the user |

Stage only the Include bucket:
```bash
git add path/to/file1 path/to/file2  # specific files, never git add -A blindly
```

If a `.env`, credentials file, or large binary is detected in the staged set, STOP and warn the user before proceeding.

### Step 3 — Analyze the Diff and Generate a Commit Message

Read the staged diff:
```bash
git diff --cached
```

Derive the commit message using these rules:
- **Prefix**: use conventional commits — `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`
- **Scope** (optional): the module or area affected, e.g., `feat(auth):` or `fix(api):`
- **Subject**: imperative mood, present tense, under 72 characters, no period at the end
- **Body** (when needed): 2-4 lines explaining the *why*, not the *what* — the diff already shows what

Good examples:
```
feat(auth): add refresh token rotation on login
fix(api): handle null response from Stripe webhook
refactor: extract payment logic into service layer
chore: upgrade TypeScript to 5.4 and fix resulting type errors
```

Bad examples (do not use):
```
Update files
Fixed stuff
WIP
Minor changes
```

### Step 4 — Run Pre-Commit Hooks (and Handle Failures)

Attempt the commit:
```bash
git commit -m "$(cat <<'EOF'
[generated message here]

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

**If the commit succeeds:** Report the commit hash and message. Done.

**If a pre-commit hook fails:**
1. Read the hook output carefully — identify exactly what it flagged
2. Do NOT use `--no-verify` to bypass the hook unless the user explicitly requests it
3. Apply the required fixes (lint errors, format issues, type errors)
4. Re-stage the affected files
5. Create a NEW commit — do not amend (amending after a failed hook risks losing the previous commit)

### Step 5 — Verify

After a successful commit:
```bash
git log --oneline -3
git show --stat HEAD
```

Confirm the commit contains exactly what was intended — correct files, correct message.

## Unstaged Change Warning

If files are left unstaged intentionally, report them clearly so the user knows their state:

```
Unstaged (left for a separate commit):
  - src/utils/unrelated-fix.ts — touches unrelated utilities
  - .env.local — never commit secrets
```

## Quick Mode

If the argument provided is a specific scope or issue reference (e.g., `fixes #42`), incorporate it directly into the commit message subject or footer.

---

*Part of the AIBR Agent Framework. Get the full 50+ skill suite at https://aiboosted4.gumroad.com/l/claude-code-power-user*
