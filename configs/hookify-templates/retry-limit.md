---
name: retry-limit
enabled: true
event: bash
pattern: (pip\s+install|git\s+push|tsc|npm\s+run\s+build|npx\s+next\s+build)
action: warn
---

If this command has already failed 3+ times in this session:
1. STOP retrying the same approach
2. Analyze the root cause
3. Try a completely different approach

Common alternatives:
- pip install failing → check venv, try pip cache purge, or use a fresh venv
- git push failing → check remote, auth, force-push guards
- build failing → check dependency versions, clear caches (rm -rf .next node_modules)

Do NOT retry the same command more than 3 times.
