#!/usr/bin/env bash
# =============================================================================
# inject-git-state.sh — SessionStart Hook
# =============================================================================
# PURPOSE:
#   Injects a compact git state summary (branch, dirty files, recent commits)
#   into the session's additionalContext at startup. This gives Claude
#   immediate awareness of repo state without burning tool calls on manual
#   `git status` / `git log` commands.
#
# HOW TO WIRE (settings.json):
#   {
#     "hooks": {
#       "SessionStart": [
#         { "type": "command", "command": "bash ~/.claude/hooks/session-start/inject-git-state.sh" }
#       ]
#     }
#   }
#
# OUTPUT FORMAT:
#   Prints JSON to stdout in the Claude Code hook additionalContext format:
#   {
#     "hookSpecificOutput": {
#       "hookEventName": "SessionStart",
#       "additionalContext": "GIT STATE [project-name] (/path/to/repo):\n  Branch: main\n  ..."
#     }
#   }
#
# REGISTRY:
#   Reads ~/.claude/projects-registry.json to match the current working
#   directory against registered projects. If no match is found, exits silently.
#   Registry format:
#   {
#     "projects": [
#       { "name": "My Project", "local_path": "~/Code/my-project" }
#     ]
#   }
#
# CUSTOMIZATION:
#   If you don't use a registry, replace the match logic with a simple check
#   for whether the current directory is inside a git repo:
#     git rev-parse --show-toplevel 2>/dev/null
# =============================================================================

set -e

python3 - <<'PYEOF'
import json, os, sys, subprocess

registry_path = os.path.expanduser("~/.claude/projects-registry.json")
cwd = os.getcwd()

try:
    with open(registry_path) as f:
        registry = json.load(f)
except Exception:
    # No registry or unreadable — exit silently, no injection
    sys.exit(0)

# Find the deepest matching project path (most-specific wins)
matched_project = None
matched_path = None
for project in registry.get("projects", []):
    local_path = project.get("local_path", "")
    if not local_path:
        continue
    expanded = os.path.expanduser(local_path)
    if cwd.startswith(expanded.rstrip("/")):
        if matched_path is None or len(expanded) > len(matched_path):
            matched_project = project
            matched_path = expanded

if not matched_project:
    # Not in a registered project directory — exit silently
    sys.exit(0)

repo_path = os.path.expanduser(matched_project["local_path"])

def run(cmd, cwd=None):
    try:
        return subprocess.check_output(cmd, cwd=cwd, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

branch = run(["git", "branch", "--show-current"], cwd=repo_path)
if not branch:
    sys.exit(0)  # Not a git repo or detached HEAD

log = run(["git", "log", "--oneline", "-5"], cwd=repo_path)
status = run(["git", "status", "--short"], cwd=repo_path)

lines = [f"GIT STATE [{matched_project['name']}] ({repo_path}):"]
lines.append(f"  Branch: {branch}")

if status:
    dirty_count = len([l for l in status.splitlines() if l.strip()])
    lines.append(f"  Uncommitted: {dirty_count} file(s)")
    # Show up to 8 dirty files
    for l in status.splitlines()[:8]:
        lines.append(f"    {l}")
    if dirty_count > 8:
        lines.append(f"    ... and {dirty_count - 8} more")
else:
    lines.append("  Working tree: clean")

if log:
    lines.append("  Recent commits:")
    for l in log.splitlines():
        lines.append(f"    {l}")

context = "\n".join(lines)
output = {
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context
    }
}
print(json.dumps(output))
PYEOF
