---
name: pr
description: Create a well-structured pull request for the current branch — analyzes all commits since diverging from main, drafts a clear title and description, then opens the PR via GitHub CLI
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
user_invocable: true
argument-hint: "[optional: additional context about the PR, e.g. 'closes #42' or 'draft']"
---

# Create Pull Request

Create a pull request for the current branch.

## Process

### Step 1: Analyze All Changes

Analyze all changes since diverging from main:

```bash
git log main..HEAD --oneline
git diff main...HEAD --stat
git diff main...HEAD
```

Summarize:
- How many commits
- What files changed
- The purpose and scope of the changes

### Step 2: Draft PR Title and Description

Write a PR title (under 70 chars) and description with:

- **## Summary** (1-3 bullet points — the "why")
- **## Changes** (list of key modifications — the "what")
- **## Test plan** (how to verify the changes work)

Title rules:
- Imperative mood: "Add", "Fix", "Refactor" — not "Added" or "Adding"
- Under 70 characters
- Specific enough to understand at a glance in a PR list

Description rules:
- Summary focuses on WHY, not what (the diff shows what)
- Changes section is a scannable list — one line per logical change
- Test plan should be executable steps, not vague statements

### Step 3: Create the PR

Push the branch if needed, then create the PR:

```bash
# Push current branch
git push -u origin HEAD

# Create PR
gh pr create --title "your title" --body "$(cat <<'EOF'
## Summary
- [bullet 1]
- [bullet 2]

## Changes
- [key change 1]
- [key change 2]

## Test plan
- [ ] [verification step 1]
- [ ] [verification step 2]
EOF
)"
```

### Step 4: Verify

After creating, confirm the PR URL and that it targets the correct base branch.

```bash
gh pr view
```

Report the PR URL to the user.

## Draft PRs

If the user passes `draft` as an argument, add `--draft` to the `gh pr create` command.

## Common Issues

**Branch not pushed yet:** Run `git push -u origin HEAD` first.

**Wrong base branch:** Use `--base branch-name` in the `gh pr create` command.

**Not authenticated:** Run `gh auth login` and follow the prompts.
