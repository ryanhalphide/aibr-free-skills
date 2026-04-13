---
name: hive
description: "Multi-terminal Claude Code coordination - create/join/status/claim/complete/message/leave/decompose"
version: 1.0.0
triggers:
  - "/hive"
  - "/hive create"
  - "/hive join"
  - "/hive status"
  - "/hive claim"
  - "/hive complete"
  - "/hive message"
  - "/hive leave"
  - "/hive decompose"
  - "/hive log"
aliases:
  - swarm-hive
  - multi-terminal
---

# Hive: Multi-Terminal Coordination

A file-based coordination layer enabling multiple Claude Code terminals to work as a unified swarm. Uses atomic file operations for cross-terminal task claiming, messaging, and file ownership.

**Key insight:** TeamCreate/SendMessage work within a single session. For cross-terminal coordination, the Hive uses a file-based state layer at `~/.claude/hive/`.

---

## Subcommand Router

Parse the user's `/hive` invocation and route to the correct subcommand:

| Input | Subcommand |
|-------|------------|
| `/hive create [name]` | [Create](#create) |
| `/hive join` | [Join](#join) |
| `/hive status` | [Status](#status) |
| `/hive claim [task-id\|--next]` | [Claim](#claim) |
| `/hive complete [task-id]` | [Complete](#complete) |
| `/hive message [target] [content]` | [Message](#message) |
| `/hive leave` | [Leave](#leave) |
| `/hive decompose [description]` | [Decompose](#decompose) |
| `/hive log [--count N]` | [Log](#log) |
| `/hive` (no args) | [Status](#status) (if active hive) or help |

---

## Constants

```
HIVE_DIR="$HOME/.claude/hive"
TASKS_DIR="$HIVE_DIR/tasks"
MEMBERS_DIR="$HIVE_DIR/members"
INBOX_DIR="$HIVE_DIR/inbox"
RESULTS_DIR="$HIVE_DIR/results"
OWNERSHIP_FILE="$HIVE_DIR/ownership/manifest.json"
CONFIG_FILE="$HIVE_DIR/config.json"
LOG_FILE="$HIVE_DIR/log/events.jsonl"
```

---

<a name="create"></a>
## `/hive create [name]`

**Purpose:** Create a new hive and become the Lead terminal.

**Steps:**

1. **Check for existing hive** — if `config.json` exists and has active members, warn and ask to confirm overwrite.

2. **Generate terminal ID** — Run this bash to get a unique ID:
```bash
TERM_ID="term-$(openssl rand -hex 4)"
echo "$TERM_ID" > "$HOME/.claude/hive/.my-terminal-id"
```

3. **Create config.json:**
```bash
HIVE_NAME="${1:-$(basename $(pwd))}"
cat > "$HOME/.claude/hive/config.json" << EOF
{
  "name": "$HIVE_NAME",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "lead_terminal": "$TERM_ID",
  "status": "active"
}
EOF
```

4. **Register as Lead member:**
```bash
cat > "$HOME/.claude/hive/members/$TERM_ID.json" << EOF
{
  "terminal_id": "$TERM_ID",
  "role": "lead",
  "specialization": "orchestrator",
  "pid": $$,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "heartbeat": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "current_task": null,
  "tasks_completed": 0,
  "status": "idle"
}
EOF
```

5. **Create inbox directory:**
```bash
mkdir -p "$HOME/.claude/hive/inbox/$TERM_ID"
```

6. **Reset ownership manifest:**
```bash
echo '{}' > "$HOME/.claude/hive/ownership/manifest.json"
```

7. **Clear any stale tasks:**
```bash
rm -f "$HOME/.claude/hive/tasks/pending/"*.json 2>/dev/null
rm -f "$HOME/.claude/hive/tasks/claimed/"*.json 2>/dev/null
rm -f "$HOME/.claude/hive/tasks/completed/"*.json 2>/dev/null
rm -f "$HOME/.claude/hive/tasks/blocked/"*.json 2>/dev/null
```

8. **Log event:**
```bash
echo '{"event":"hive_created","terminal":"'$TERM_ID'","name":"'$HIVE_NAME'","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' >> "$HOME/.claude/hive/log/events.jsonl"
```

9. **Display output:**
```
╔══════════════════════════════════════════════════╗
║            HIVE CREATED: {name}                  ║
╠══════════════════════════════════════════════════╣
║ Role: Lead (Orchestrator)                        ║
║ ID:   {terminal-id}                              ║
╠══════════════════════════════════════════════════╣
║ Other terminals can join with:                   ║
║   /hive join                                     ║
║                                                  ║
║ Decompose work with:                             ║
║   /hive decompose "description of work"          ║
╚══════════════════════════════════════════════════╝
```

---

<a name="join"></a>
## `/hive join`

**Purpose:** Join an existing hive as a Worker terminal.

**Steps:**

1. **Detect active hive** — Check if `config.json` exists and has `status: "active"`.
   - If no hive: print "No active hive found. Create one with: /hive create [name]" and stop.

2. **Generate terminal ID:**
```bash
TERM_ID="term-$(openssl rand -hex 4)"
echo "$TERM_ID" > "$HOME/.claude/hive/.my-terminal-id"
```

3. **Auto-detect specialization** — Ask the user or default to `generalist`:
   - If the user included a specialization hint, use it
   - Options: `builder`, `verifier`, `reviewer`, `deployer`, `explorer`, `generalist`
   - Default: `generalist`

4. **Register as Worker member:**
```bash
SPEC="${1:-generalist}"
cat > "$HOME/.claude/hive/members/$TERM_ID.json" << EOF
{
  "terminal_id": "$TERM_ID",
  "role": "worker",
  "specialization": "$SPEC",
  "pid": $$,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "heartbeat": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "current_task": null,
  "tasks_completed": 0,
  "status": "idle"
}
EOF
```

5. **Create inbox:**
```bash
mkdir -p "$HOME/.claude/hive/inbox/$TERM_ID"
```

6. **Log event:**
```bash
echo '{"event":"member_joined","terminal":"'$TERM_ID'","role":"worker","specialization":"'$SPEC'","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' >> "$HOME/.claude/hive/log/events.jsonl"
```

7. **Check for available tasks** — List pending tasks matching specialization.

8. **Display output:**
```
╔══════════════════════════════════════════════════╗
║           JOINED HIVE: {name}                    ║
╠══════════════════════════════════════════════════╣
║ Role: Worker ({specialization})                  ║
║ ID:   {terminal-id}                              ║
║ Lead: {lead-terminal-id}                         ║
╠══════════════════════════════════════════════════╣
║ Pending tasks: {count}                           ║
║ Claim next with: /hive claim --next              ║
╚══════════════════════════════════════════════════╝
```

---

<a name="status"></a>
## `/hive status`

**Purpose:** Show hive state dashboard.

**Steps:**

1. **Read config.json** for hive name.

2. **Scan members/** — Read all member JSON files. Mark stale (heartbeat > 120s ago).

3. **Count tasks by status** — Count files in `tasks/pending/`, `tasks/claimed/`, `tasks/completed/`, `tasks/blocked/`.

4. **Read ownership manifest** — Group file ownerships by terminal.

5. **Check inbox depths** — Count unread messages per terminal.

6. **Render dashboard:**

```bash
#!/bin/bash
HIVE_DIR="$HOME/.claude/hive"
NOW_EPOCH=$(date +%s)

# Read hive config
HIVE_NAME=$(jq -r '.name' "$HIVE_DIR/config.json" 2>/dev/null || echo "unknown")
HIVE_STATUS=$(jq -r '.status // "active"' "$HIVE_DIR/config.json" 2>/dev/null)
LEAD_ID=$(jq -r '.lead_terminal // "none"' "$HIVE_DIR/config.json" 2>/dev/null)

# Count tasks
PENDING=$(ls "$HIVE_DIR/tasks/pending/" 2>/dev/null | grep -c '.json$' || echo 0)
CLAIMED=$(ls "$HIVE_DIR/tasks/claimed/" 2>/dev/null | grep -c '.json$' || echo 0)
COMPLETED=$(ls "$HIVE_DIR/tasks/completed/" 2>/dev/null | grep -c '.json$' || echo 0)
BLOCKED=$(ls "$HIVE_DIR/tasks/blocked/" 2>/dev/null | grep -c '.json$' || echo 0)
TOTAL=$((PENDING + CLAIMED + COMPLETED + BLOCKED))

# Get my terminal ID and unread count
MY_ID=$(cat "$HIVE_DIR/.my-terminal-id" 2>/dev/null || echo "unknown")
MY_UNREAD=$(ls "$HIVE_DIR/inbox/$MY_ID/"*.json 2>/dev/null | wc -l | tr -d ' ')
```

**Then output the dashboard in this exact format:**

```
╔══════════════════════════════════════════════════════════╗
║  HIVE: {name}                          Status: {status} ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  Progress: [{bar}] {pct}%  ({completed}/{total} tasks)   ║
║                                                          ║
║  TASKS                                                   ║
║  ├─ Pending:   {pending}                                 ║
║  ├─ In Work:   {claimed}                                 ║
║  ├─ Blocked:   {blocked}                                 ║
║  └─ Done:      {completed}                               ║
║                                                          ║
║  MEMBERS ({count})                                       ║
║  ┌──────────────┬──────────┬───────────┬────────────┐    ║
║  │ Terminal     │ Role     │ Status    │ Task       │    ║
║  ├──────────────┼──────────┼───────────┼────────────┤    ║
║  │ {term-id}    │ {role}   │ {status}  │ {task-id}  │    ║
║  └──────────────┴──────────┴───────────┴────────────┘    ║
║                                                          ║
║  OWNERSHIP                                               ║
║  {file} → {terminal}                                     ║
║                                                          ║
║  INBOX: {unread} unread message(s)                       ║
╚══════════════════════════════════════════════════════════╝
```

---

<a name="claim"></a>
## `/hive claim [task-id|--next]`

**Purpose:** Claim a task from the pending queue.

### If `task-id` is specified:
1. Check if `tasks/pending/{task-id}.json` exists.
2. If not, check `tasks/blocked/` — if there, explain the dependency.
3. **Atomic claim via mv:**
```bash
TASK_ID="$1"
mv "$HOME/.claude/hive/tasks/pending/$TASK_ID.json" \
   "$HOME/.claude/hive/tasks/claimed/$TASK_ID.json" 2>/dev/null
if [ $? -eq 0 ]; then
  echo "CLAIMED"
else
  echo "FAILED - task may already be claimed"
fi
```
4. If `mv` succeeds: update `claimed_by`, `claimed_at`, `status` fields in the JSON.
5. Register file ownership for the task's `files` array.
6. Update own member JSON: set `current_task` and `status: "working"`.

### If `--next` (auto-select):
1. Read own specialization from member JSON.
2. List all files in `tasks/pending/`.
3. For each, read JSON and filter:
   - `type` matches specialization (or specialization is `generalist`)
   - `depends_on` array is empty or all dependencies in `tasks/completed/`
4. Sort by `priority` (1 = highest).
5. Attempt atomic `mv` on the first match.
6. If claimed, update fields and register ownership.
7. If no compatible task found, report "No compatible pending tasks."

### After successful claim:
```bash
TERM_ID=$(cat "$HOME/.claude/hive/.my-terminal-id")
TASK_FILE="$HOME/.claude/hive/tasks/claimed/$TASK_ID.json"
TMP=$(mktemp)
jq --arg tid "$TERM_ID" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '.claimed_by = $tid | .claimed_at = $now | .status = "in_progress"' \
  "$TASK_FILE" > "$TMP" && mv "$TMP" "$TASK_FILE"

# Register file ownership
for f in $(jq -r '.files[]' "$TASK_FILE" 2>/dev/null); do
  TMP2=$(mktemp)
  jq --arg f "$f" --arg tid "$TERM_ID" '.[$f] = $tid' \
    "$HOME/.claude/hive/ownership/manifest.json" > "$TMP2" \
    && mv "$TMP2" "$HOME/.claude/hive/ownership/manifest.json"
done

# Update member status
MEMBER_FILE="$HOME/.claude/hive/members/$TERM_ID.json"
TMP3=$(mktemp)
jq --arg tid "$TASK_ID" '.current_task = $tid | .status = "working"' \
  "$MEMBER_FILE" > "$TMP3" && mv "$TMP3" "$MEMBER_FILE"

echo '{"event":"task_claimed","terminal":"'$TERM_ID'","task":"'$TASK_ID'","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
  >> "$HOME/.claude/hive/log/events.jsonl"
```

**Display:**
```
Claimed: {task-id}
Title:   {title}
Type:    {type}
Files:   {files list}

Begin work now. When done: /hive complete {task-id}
```

**Then read the task description and begin executing it** using the appropriate agent type (builder for build tasks, verifier for verify tasks, etc.).

---

<a name="complete"></a>
## `/hive complete [task-id] [--result "summary"]`

**Purpose:** Mark current task as completed.

**Steps:**

1. **Determine task ID** — If not provided, read `current_task` from own member JSON.

2. **Move task to completed:**
```bash
TASK_ID="$1"
mv "$HOME/.claude/hive/tasks/claimed/$TASK_ID.json" \
   "$HOME/.claude/hive/tasks/completed/$TASK_ID.json"
```

3. **Update task fields:**
```bash
TASK_FILE="$HOME/.claude/hive/tasks/completed/$TASK_ID.json"
RESULT="${2:-Task completed successfully}"
TMP=$(mktemp)
jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg r "$RESULT" \
  '.completed_at = $now | .status = "completed" | .result = $r' \
  "$TASK_FILE" > "$TMP" && mv "$TMP" "$TASK_FILE"
```

4. **Write result artifact:**
```bash
cp "$TASK_FILE" "$HOME/.claude/hive/results/$TASK_ID.json"
```

5. **Release file ownership:**
```bash
for f in $(jq -r '.files[]' "$TASK_FILE" 2>/dev/null); do
  TMP2=$(mktemp)
  jq --arg f "$f" 'del(.[$f])' \
    "$HOME/.claude/hive/ownership/manifest.json" > "$TMP2" \
    && mv "$TMP2" "$HOME/.claude/hive/ownership/manifest.json"
done
```

6. **Unblock dependent tasks:**
```bash
for blocked_file in "$HOME/.claude/hive/tasks/blocked/"*.json; do
  [ -f "$blocked_file" ] || continue
  STILL_BLOCKED=false
  jq -r '.depends_on[]' "$blocked_file" 2>/dev/null | while IFS= read -r dep; do
    [ -z "$dep" ] && continue
    if [ ! -f "$HOME/.claude/hive/tasks/completed/${dep}.json" ]; then
      touch /tmp/hive_still_blocked
    fi
  done
  if [ -f /tmp/hive_still_blocked ]; then
    STILL_BLOCKED=true
    rm -f /tmp/hive_still_blocked
  fi
  if [ "$STILL_BLOCKED" = "false" ]; then
    BLOCKED_ID=$(jq -r '.id' "$blocked_file")
    mv "$blocked_file" "$HOME/.claude/hive/tasks/pending/$(basename $blocked_file)"
    echo "Unblocked: $BLOCKED_ID"
  fi
done
```

7. **Update member status:**
```bash
TERM_ID=$(cat "$HOME/.claude/hive/.my-terminal-id")
MEMBER_FILE="$HOME/.claude/hive/members/$TERM_ID.json"
TMP4=$(mktemp)
jq '.current_task = null | .status = "idle" | .tasks_completed += 1' \
  "$MEMBER_FILE" > "$TMP4" && mv "$TMP4" "$MEMBER_FILE"
```

8. **Display:**
```
Completed: {task-id} - {title}
Result: {result summary}
Unblocked: {list of unblocked tasks, if any}

{count} pending tasks remaining. Claim next? /hive claim --next
```

---

<a name="message"></a>
## `/hive message [target] [content]`

**Purpose:** Send a message to another terminal or broadcast.

**Targets:**
- `lead` — Send to the lead terminal
- `all` — Broadcast to all members
- `{terminal-id}` — Direct message to a specific terminal

**Steps:**

1. **Resolve target:**
```bash
TARGET="$1"
CONTENT="$2"
FROM=$(cat "$HOME/.claude/hive/.my-terminal-id")
MSG_ID="msg-$(openssl rand -hex 6)"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [ "$TARGET" = "lead" ]; then
  TARGET_ID=$(jq -r '.lead_terminal' "$HOME/.claude/hive/config.json")
elif [ "$TARGET" = "all" ]; then
  TARGET_ID="broadcast"
else
  TARGET_ID="$TARGET"
fi
```

2. **Create message JSON:**
```json
{
  "id": "{msg-id}",
  "from": "{from-terminal-id}",
  "to": "{target}",
  "type": "message",
  "content": "{content}",
  "timestamp": "{timestamp}",
  "read": false
}
```

3. **Deliver message:**
```bash
if [ "$TARGET_ID" = "broadcast" ]; then
  for member_dir in "$HOME/.claude/hive/inbox/"*/; do
    MEMBER_ID=$(basename "$member_dir")
    [ "$MEMBER_ID" = "$FROM" ] && continue
    cat > "$member_dir/$MSG_ID.json" << MSGEOF
{"id":"$MSG_ID","from":"$FROM","to":"$MEMBER_ID","type":"broadcast","content":"$CONTENT","timestamp":"$TIMESTAMP","read":false}
MSGEOF
  done
else
  mkdir -p "$HOME/.claude/hive/inbox/$TARGET_ID"
  cat > "$HOME/.claude/hive/inbox/$TARGET_ID/$MSG_ID.json" << MSGEOF
{"id":"$MSG_ID","from":"$FROM","to":"$TARGET_ID","type":"message","content":"$CONTENT","timestamp":"$TIMESTAMP","read":false}
MSGEOF
fi
```

4. **Display:** `Message sent to {target}: "{content}"`

---

## Reading Inbox

```bash
MY_ID=$(cat "$HOME/.claude/hive/.my-terminal-id")
INBOX="$HOME/.claude/hive/inbox/$MY_ID"
UNREAD=$(ls "$INBOX/"*.json 2>/dev/null | wc -l | tr -d ' ')

if [ "$UNREAD" -gt 0 ]; then
  echo "$UNREAD unread hive message(s):"
  for msg_file in "$INBOX/"*.json; do
    FROM=$(jq -r '.from' "$msg_file")
    CONTENT=$(jq -r '.content' "$msg_file")
    TYPE=$(jq -r '.type' "$msg_file")
    TIMESTAMP=$(jq -r '.timestamp' "$msg_file")
    echo "  [$TYPE] From $FROM at $TIMESTAMP: $CONTENT"
    rm "$msg_file"
  done
fi
```

---

<a name="leave"></a>
## `/hive leave`

**Purpose:** Gracefully leave the hive.

**Steps:**

1. Get own terminal ID and role.

2. **Release current task** — If working on a task, move it back to pending.

3. **Release all file ownership.**

4. **Remove inbox.**

5. **Remove member registration.**

6. **If Lead leaving:**
   - Count remaining members
   - If members exist: promote the longest-running worker to lead
   - If no members: set hive status to "dissolved"

7. **Clean up local state:** `rm -f "$HOME/.claude/hive/.my-terminal-id"`

8. **Display:** `Left hive: {name}`

---

<a name="decompose"></a>
## `/hive decompose [description]`

**Purpose:** Lead-only. Break a high-level task into subtasks with dependencies.

**Prerequisites:** Must be the Lead terminal (check `role` in member JSON).

**Steps:**

1. Verify Lead role.

2. **Analyze the description** to break it into subtasks. For each subtask, determine:
   - `id`: Generate with `task-$(openssl rand -hex 6)`
   - `title`: Concise task name
   - `description`: Detailed work description
   - `type`: `build|verify|review|deploy|explore|plan`
   - `priority`: 1-5 (1 = highest)
   - `depends_on`: Array of task IDs that must complete first
   - `files`: Array of file paths this task will touch
   - `metadata.agent_type`: Which specialist agent should handle this
   - `metadata.estimated_complexity`: `low|medium|high`

3. **Generate task dependency chain** — Ensure:
   - Schema/model tasks come first
   - Implementation depends on schema
   - Tests depend on implementation
   - No circular dependencies

4. **Create task files** — Tasks with unresolved deps go to `blocked/`, others go to `pending/`.

5. **Register file ownership boundaries** — Non-overlapping file ownership per task.

6. **Broadcast task availability** to all workers.

7. **Display decomposition summary:**
```
╔══════════════════════════════════════════════════╗
║        DECOMPOSED: {description}                 ║
╠══════════════════════════════════════════════════╣
║ Created {total} tasks:                           ║
║  1. [build]   {task-1-title}         priority:1  ║
║  2. [build]   {task-2-title}  ← 1   priority:2  ║
║  3. [verify]  {task-3-title}  ← 2   priority:3  ║
║                                                  ║
║ Ready now: {ready-count} tasks                   ║
║ Blocked:   {blocked-count} tasks                 ║
╚══════════════════════════════════════════════════╝
```

---

<a name="log"></a>
## `/hive log [--count N]`

Render the event log in human-readable format. Default shows last 20 events.

```bash
COUNT=20
LOG_FILE="$HIVE_DIR/log/events.jsonl"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  HIVE EVENT LOG (last $COUNT of $TOTAL_EVENTS events)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  %-20s %-22s %-14s %s\n" "TIMESTAMP" "EVENT" "TERMINAL" "DETAIL"

tail -"$COUNT" "$LOG_FILE" | while IFS= read -r line; do
  TS=$(echo "$line" | jq -r '.timestamp // "?"')
  EVT=$(echo "$line" | jq -r '.event // "unknown"')
  TERM=$(echo "$line" | jq -r '.terminal // "-"')
  TASK=$(echo "$line" | jq -r '.task // .name // "-"')
  printf "  %-20s %-20s %-14s %s\n" "$TS" "$EVT" "$TERM" "$TASK"
done
```

**Legend:**
```
+ = created/joined    > = claimed    * = completed
^ = unblocked         @ = message    - = left
```

---

## GSD Bridge

Maps hive tasks to GSD phases so `/gsd:progress` reflects hive task completion.

When `/hive decompose` creates tasks, the `metadata` field can include phase references:

```json
{
  "metadata": {
    "project": "my-project",
    "gsd_phase": "3",
    "gsd_plan": "3.2",
    "agent_type": "builder",
    "estimated_complexity": "medium"
  }
}
```

When `/gsd:progress` runs and a hive is active, it checks hive task state to report combined progress across manual tasks and hive-dispatched subtasks.
