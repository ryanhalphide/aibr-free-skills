# Auto-Diagnose — Self-Healing Error Categorization

## The Problem

Bash errors are cryptic. "Exit code 1" tells Claude nothing. "npm ERR! code ERESOLVE" is slightly less cryptic but still requires interpretation. Without knowing *what kind* of failure occurred, Claude's default behavior is to re-read the error, form a guess, and try something. If that doesn't work, try something else.

This creates thrashing loops. Claude spends 4-5 tool calls iterating through variations of the wrong fix because it never understood the root cause. Common loops:
- Running `npm install` repeatedly when the real issue is a git lock file
- Re-running a server start when the real issue is a port conflict
- Retrying an API call when the real issue is an expired auth token

The fix isn't trying harder — it's categorizing the failure correctly on the first attempt.

## The Pattern

A PostToolUse hook that intercepts every Bash tool failure. It reads stderr/stdout from the failed command, pattern-matches against 25+ known error categories, and outputs a structured fix prescription that Claude reads before deciding what to do next.

The hook runs silently on success (zero context cost). It only activates on failure.

## The 25+ Error Patterns

| Category | Pattern Matched | Prescribed Action |
|----------|-----------------|-------------------|
| `git-lock` | "Another git process seems to be running" | `rm -f .git/index.lock` |
| `port-in-use` | "EADDRINUSE", "address already in use" | Kill the process on that port |
| `eacces` | "EACCES", "Permission denied" | Check file permissions, sudo if appropriate |
| `enoent` | "ENOENT", "no such file or directory" | Verify path, check if file was moved/deleted |
| `module-not-found-npm` | "Cannot find module", "MODULE_NOT_FOUND" | Run `npm install` |
| `module-not-found-py` | "ModuleNotFoundError", "No module named" | Run `pip install` for missing module |
| `typescript-error` | "TS2", "error TS", "TypeScript" | Read the specific TS error code |
| `rate-limit` | "429", "rate limit", "too many requests" | Wait and retry with backoff |
| `auth-401` | "401", "Unauthorized", "invalid token" | Refresh auth token / check credentials |
| `auth-403` | "403", "Forbidden", "not authorized" | Check permissions / scope |
| `connection-refused` | "ECONNREFUSED", "connection refused" | Check if target service is running |
| `timeout` | "ETIMEDOUT", "timed out", "TIMEOUT" | Check network / increase timeout |
| `oom` | "JavaScript heap out of memory", "OOM" | Increase `--max-old-space-size` |
| `docker-not-running` | "Cannot connect to the Docker daemon" | Start Docker / check context |
| `docker-image-missing` | "Unable to find image", "pull access denied" | Pull image or build locally |
| `npm-install-fail` | "npm ERR! code ERESOLVE" | Clear `node_modules` + `package-lock.json`, reinstall |
| `pip-install-fail` | "pip._internal.exceptions" | Check Python version, try `--user` flag |
| `missing-env-var` | "undefined", missing env references | Check `.env` file for the var |
| `ssh-key` | "Permission denied (publickey)" | Check SSH agent / key loaded |
| `ssl-cert` | "SSL certificate", "CERT_HAS_EXPIRED" | Check cert validity / use `--insecure` carefully |
| `disk-full` | "ENOSPC", "no space left on device" | Free disk space |
| `cors` | "CORS", "Access-Control-Allow-Origin" | Check server CORS config |
| `db-connection` | "could not connect to server", "ECONNREFUSED:5432" | Check database service is running |
| `migration-conflict` | "migration", "duplicate key", "already exists" | Check migration history |
| `test-assertion` | "AssertionError", "Expected", "toBe" | Read the failing assertion carefully |
| `linter-error` | "ESLint", "Prettier", "eslint" | Run linter directly for full output |
| `build-size` | "exceeds", "chunk too large" | Check bundle analyzer |

## Example Output

When Claude runs a git command on a repo with a stale lock file:

```
ERROR CATEGORY: git-lock
PATTERN: "Another git process seems to be running"
PRESCRIBED ACTION: rm -f /path/to/repo/.git/index.lock
Then retry the original git command.
PREVENTION: Run git commands sequentially, not in parallel terminals.
```

Claude reads this, runs the prescribed action, and retries. One tool call instead of four.

## Why the Silent-on-Success Rule Matters

The hook adds zero cost to successful operations. No output, no context consumed, no distraction. It's only active when something breaks — exactly when you need it most.

This is the "pays for itself" design: the hook has no downside on good paths and significant upside on bad paths.

## Composing With Other Hooks

`auto-diagnose.sh` pairs well with a retry-limit hookify rule that blocks after 3 consecutive failures of the same type. Together they create a self-healing loop with a hard stop: diagnose → prescribe → retry → if still failing after N attempts, surface to user.

## Implementation

See: [`hooks/post-tool/auto-diagnose.sh`](../hooks/post-tool/auto-diagnose.sh)
