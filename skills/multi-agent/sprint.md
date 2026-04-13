---
name: sprint
description: "Isolated parallel agent sprints — spawn multiple Claude agents in separate git worktrees with conflict detection and clean merging"
version: 1.0.0
triggers:
  - "/sprint"
  - "/sprint create"
  - "/sprint status"
  - "/sprint merge"
  - "/sprint cleanup"
aliases:
  - parallel-sprint
  - isolated-sprint
---

# Sprint: Isolated Parallel Agent Work

Run multiple Claude agents on independent workstreams, each in its own **git worktree** — preventing venv corruption and file conflicts from parallel sprints.

---

## Subcommand Router

| Input | Action |
|-------|--------|
| `/sprint create [description]` | [Create Sprint](#create) |
| `/sprint status` | [Status](#status) |
| `/sprint merge` | [Merge](#merge) |
| `/sprint cleanup` | [Cleanup](#cleanup) |
| `/sprint` (no args) | Status if active, else prompt to create |

---

## Constants

```
SPRINT_DIR="$HOME/.claude/sprint"
WORKTREES_DIR="$SPRINT_DIR/worktrees"
SPRINT_CONFIG="$SPRINT_DIR/config.json"
SPRINT_LOG="$SPRINT_DIR/log.jsonl"
```

---

## Create

### Step 1: Validate Prerequisites

```bash
# Must be in a git repo
cd "$PROJECT_DIR" && git rev-parse --is-inside-work-tree || { echo "ERROR: Not a git repo"; exit 1; }

# Must have clean working tree (stash or commit first)
git diff --quiet && git diff --cached --quiet || { echo "ERROR: Uncommitted changes. Commit or stash first."; exit 1; }

# Must not be in iCloud
[[ "$PROJECT_DIR" != "$HOME/Desktop"* ]] && [[ "$PROJECT_DIR" != "$HOME/Documents"* ]] || { echo "ERROR: Repo in iCloud. Move to ~/Code/"; exit 1; }
```

### Step 2: Gather Tasks

If the user provides a description, decompose it into 2-6 independent tasks using this schema:

```yaml
# sprint-tasks.yaml — written to $SPRINT_DIR/tasks.yaml
sprint_name: "descriptive-name"
base_branch: "main"  # or current branch
repo: "/absolute/path/to/repo"
created_at: "2026-03-18T10:00:00Z"
tasks:
  - id: task-1
    title: "Short title"
    description: "What to implement"
    type: build  # build|verify|explore|deploy
    files:       # File boundaries — EXCLUSIVE per task, no overlaps
      - "src/auth/**"
      - "src/middleware/**"
    branch: "sprint/descriptive-name/task-1"
    priority: 1
    depends_on: []  # task IDs this blocks on

  - id: task-2
    title: "Another task"
    description: "What to implement"
    type: build
    files:
      - "src/api/**"
      - "src/utils/format*"
    branch: "sprint/descriptive-name/task-2"
    priority: 1
    depends_on: []
```

**CRITICAL RULES for task decomposition:**
- **File boundaries must not overlap.** If two tasks touch the same file, they CANNOT be parallel. Merge them or sequence them with `depends_on`.
- **Each task gets its own git branch** under `sprint/<name>/task-<id>`.
- **2-6 tasks maximum.** More than 6 = too fragmented. Fewer than 2 = just do it sequentially.
- **Dependency-free tasks first.** Tasks with `depends_on: []` run immediately. Dependent tasks wait.
- **Estimate complexity** — low (<30min), medium (30-60min), high (60min+). High complexity tasks should be decomposed further.

### Step 3: Create Worktrees

For each task, create an isolated git worktree:

```bash
# Create sprint directory structure
mkdir -p "$SPRINT_DIR/worktrees" "$SPRINT_DIR/results" "$SPRINT_DIR/logs"

# For each task:
TASK_BRANCH="sprint/${SPRINT_NAME}/task-${TASK_ID}"
WORKTREE_PATH="$SPRINT_DIR/worktrees/task-${TASK_ID}"

# Create branch and worktree
git branch "$TASK_BRANCH" "${BASE_BRANCH}" 2>/dev/null
git worktree add "$WORKTREE_PATH" "$TASK_BRANCH"

echo "Created worktree: $WORKTREE_PATH on branch $TASK_BRANCH"
```

### Step 4: Create Sprint Config

```bash
cat > "$SPRINT_CONFIG" <<EOF
{
  "name": "${SPRINT_NAME}",
  "repo": "${PROJECT_DIR}",
  "base_branch": "${BASE_BRANCH}",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "active",
  "tasks": [
    // ... task objects with worktree paths and status
  ]
}
EOF
```

### Step 5: Write Hive Tasks

For each sprint task, create a hive task file so `/hive` workers can claim them:

```bash
for task in tasks; do
  cat > "$HOME/.claude/hive/tasks/pending/task-${TASK_ID}.json" <<EOF
  {
    "id": "task-${TASK_ID}",
    "title": "${TASK_TITLE}",
    "description": "${TASK_DESC}",
    "type": "${TASK_TYPE}",
    "priority": ${TASK_PRIORITY},
    "status": "pending",
    "claimed_by": null,
    "depends_on": ${TASK_DEPS},
    "blocks": [],
    "files": ${TASK_FILES},
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "metadata": {
      "sprint": "${SPRINT_NAME}",
      "worktree": "${WORKTREE_PATH}",
      "branch": "${TASK_BRANCH}",
      "isolation": "worktree",
      "agent_type": "builder",
      "estimated_complexity": "medium"
    }
  }
EOF
done
```

### Step 6: Launch Workers

Tell the user to open additional terminals and run `/hive join` in each. Each worker will:
1. Claim a pending task
2. `cd` into the task's worktree directory
3. Work in complete isolation
4. Commit results to the task's branch

**Output to user:**
```
Sprint "${SPRINT_NAME}" created with ${N} tasks.

Worktrees:
  task-1: ${WORKTREE_1} (branch: sprint/${NAME}/task-1)
  task-2: ${WORKTREE_2} (branch: sprint/${NAME}/task-2)
  ...

Next steps:
  1. Open ${N} additional terminals
  2. In each: cd ${PROJECT_DIR} && claude
  3. Run: /hive join
  4. Workers auto-claim tasks and work in isolated worktrees
  5. When all done: /sprint merge
```

### Step 7: If running in single terminal with subagents

For single-terminal sprint mode, use the Agent tool with `isolation: "worktree"`:

```
For each independent task:
  Agent(
    description: "Sprint task: ${TASK_TITLE}",
    prompt: "${TASK_DESC}\n\nWork in: ${WORKTREE_PATH}\nBranch: ${TASK_BRANCH}\nFiles: ${TASK_FILES}",
    subagent_type: "builder",
    isolation: "worktree",
    run_in_background: true
  )
```

Launch ALL independent tasks simultaneously. Wait for results. Then launch dependent tasks.

---

## Status

Read `$SPRINT_CONFIG` and show:

```
Sprint: ${NAME} (${STATUS})
Base: ${BASE_BRANCH} @ ${REPO}
Created: ${CREATED_AT}

Tasks:
  [completed] task-1: Add auth middleware (branch: sprint/name/task-1)
  [running]   task-2: Fix API formatting (claimed by term-12345)
  [pending]   task-3: Update tests (blocked by: task-1, task-2)
  [failed]    task-4: Deploy staging (error: build failed)

Progress: 1/4 complete | 1 running | 1 pending | 1 failed
```

---

## Merge

### Step 1: Pre-merge Validation

```bash
# All tasks must be completed or explicitly skipped
pending=$(jq '[.tasks[] | select(.status == "pending" or .status == "running")] | length' "$SPRINT_CONFIG")
if [ "$pending" -gt 0 ]; then
  echo "ERROR: $pending tasks still pending/running. Complete or skip them first."
  exit 1
fi
```

### Step 2: Conflict Detection

```bash
# For each completed task branch, check for conflicts against base
for task in completed_tasks; do
  TASK_BRANCH="sprint/${SPRINT_NAME}/task-${TASK_ID}"

  # Dry-run merge to detect conflicts
  git merge --no-commit --no-ff "$TASK_BRANCH" 2>&1
  if [ $? -ne 0 ]; then
    echo "CONFLICT: task-${TASK_ID} conflicts with current state"
    git merge --abort
    conflicts+=("task-${TASK_ID}")
  else
    git merge --abort  # Clean up dry-run
    clean+=("task-${TASK_ID}")
  fi
done
```

### Step 3: Sequential Merge

Merge clean branches first, then handle conflicts:

```bash
# Merge clean branches in priority order
for task_id in "${clean[@]}"; do
  TASK_BRANCH="sprint/${SPRINT_NAME}/task-${TASK_ID}"
  git merge --no-ff "$TASK_BRANCH" -m "sprint(${SPRINT_NAME}): merge task-${TASK_ID}"
  echo "Merged: task-${TASK_ID}"
done

# Report conflicts for manual resolution
if [ ${#conflicts[@]} -gt 0 ]; then
  echo ""
  echo "CONFLICTS requiring manual resolution:"
  for task_id in "${conflicts[@]}"; do
    echo "  - task-${TASK_ID}: git merge sprint/${SPRINT_NAME}/task-${TASK_ID}"
  done
fi
```

### Step 4: Post-merge Verification

After all merges:
```bash
# Run project tests/build to verify merged result
npm test 2>&1 || echo "WARNING: Tests failing after merge"
npm run build 2>&1 || echo "WARNING: Build failing after merge"
```

---

## Cleanup

Remove worktrees and sprint branches after successful merge:

```bash
# Remove worktrees
for task in all_tasks; do
  WORKTREE_PATH="$SPRINT_DIR/worktrees/task-${TASK_ID}"
  git worktree remove "$WORKTREE_PATH" --force 2>/dev/null
done

# Delete sprint branches
for task in all_tasks; do
  TASK_BRANCH="sprint/${SPRINT_NAME}/task-${TASK_ID}"
  git branch -D "$TASK_BRANCH" 2>/dev/null
done

# Archive sprint config
mv "$SPRINT_CONFIG" "$SPRINT_DIR/archive/$(date +%Y%m%d)-${SPRINT_NAME}.json"

# Clean hive tasks
rm -f "$HOME/.claude/hive/tasks/completed/task-"*.json

echo "Sprint ${SPRINT_NAME} cleaned up."
```

---

## Environment Isolation Rules

Each worktree is a FULL isolated copy. Workers MUST:

1. **Install dependencies in their worktree**: `cd $WORKTREE && npm install` (or pip install, etc.)
2. **Never share node_modules/venv** across worktrees — this caused past corruption
3. **Only touch files listed in their task's `files` array** — ownership is enforced
4. **Commit to their branch only** — never push to main/base
5. **Use separate ports** for dev servers (task-1: 3001, task-2: 3002, etc.)

### Python Projects — Extra Isolation

```bash
# Each worktree gets its own venv
cd "$WORKTREE_PATH"
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Node Projects — Extra Isolation

```bash
# Each worktree gets its own node_modules
cd "$WORKTREE_PATH"
npm install  # or pnpm install --frozen-lockfile
```

---

## Error Recovery

| Situation | Action |
|-----------|--------|
| Worker crashes mid-task | Heartbeat timeout (5min) releases the task. Another worker can reclaim. |
| Worktree corrupted | `git worktree remove --force $PATH` → recreate from branch |
| Merge conflict | Report conflicting files. User resolves manually or uses `git mergetool`. |
| All workers stuck | `/sprint status` shows stalled tasks. Lead can reassign or decompose further. |
| Task fails 3x | Mark as `failed`, move to `$SPRINT_DIR/results/task-${ID}-failed.json` with error log |
