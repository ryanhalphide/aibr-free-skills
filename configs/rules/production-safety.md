---
description: Production safety rules for all projects. Blocks dangerous actions without explicit approval.
---

# Production Safety Rules

## Hard Blocks (never do without explicit confirmation)

- Never write to a production database directly
- Never push to `main` or `master` without a PR
- Never deploy without running tests first
- Never overwrite live API keys or credentials
- Never execute destructive operations (DROP TABLE, rm -rf, force-push) without user confirmation
- Never send emails or messages to real users from test/dev environments

## Branch Protection

- All feature work on a named branch: `feature/`, `fix/`, `chore/`
- PRs required for main branch merges
- Always confirm the current branch before any commit: `git branch --show-current`

## Credential Safety

- Never log or print API keys, tokens, or passwords
- Never commit `.env` files
- Never overwrite a live key with a test/paper key without confirming with user
- Check for `# LIVE` or `# PRODUCTION` comments before modifying credential files

## Deployment Checklist (must pass before any deploy)

- [ ] Tests passing
- [ ] TypeScript clean (if applicable)
- [ ] On correct branch (not main directly)
- [ ] Environment variables verified for target environment
- [ ] User has approved the deployment
