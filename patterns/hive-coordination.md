# Hive — File-Based Multi-Terminal Swarm Coordination

## The Problem

Claude Code's built-in Agent tool and TeamCreate work within a single session. This covers most parallel work — you can dispatch 3-5 agents simultaneously from one terminal and they'll complete their tasks.

But some work genuinely requires independent terminals:
- Long-running tasks that span multiple work sessions
- Workstreams where each agent needs its own context window, tool permissions, or model tier
- Work that needs to continue while the orchestrating terminal is doing something else
- Multi-day parallel development across separate repositories

When you open two Claude Code terminals and point them at the same project, they have no awareness of each other. Both might start editing the same file. Both might claim the same task. There's no coordination layer.

## The Pattern

A shared file-based coordination layer at `~/.claude/hive/`. The Hive provides:
1. **Task queue**: pending tasks that any terminal can claim
2. **Atomic claiming**: prevents two terminals from grabbing the same task
3. **File ownership manifest**: prevents edit conflicts
4. **Cross-terminal messaging**: inbox directories per terminal
5. **Event log**: structured log of all Hive activity

## Directory Structure

```
~/.claude/hive/
├── config.json          # Active hive name, creation time, coordinator ID
├── tasks/               # task-{uuid}.json files
│   ├── task-abc123.json # { "id": "abc123", "status": "pending", "description": "...", "owner": null }
│   └── task-def456.json # { "id": "def456", "status": "claimed", "owner": "terminal-2" }
├── members/             # One heartbeat file per active terminal
│   ├── terminal-1.json  # { "pid": 12345, "dir": "~/Code/project", "last_seen": "2026-01-01T10:00:00Z" }
│   └── terminal-2.json
├── inbox/               # Cross-terminal messages
│   ├── terminal-1/      # Messages for terminal 1
│   └── terminal-2/
├── results/             # Completed task outputs
│   └── task-abc123.json # { "task_id": "abc123", "output": "...", "completed_at": "..." }
├── ownership/
│   └── manifest.json    # { "src/auth.ts": "terminal-1", "src/api.ts": "terminal-2" }
└── log/
    └── events.jsonl     # Append-only structured event log
```

## Atomic Task Claiming

The only truly atomic file operation available without OS-level primitives is `rename()`. The Hive uses it:

1. Terminal reads `tasks/` directory, finds a pending task
2. Writes a claim file to `tasks/claiming-{taskid}-{terminal-id}.json` (temp file)
3. Attempts `mv tasks/claiming-{taskid}-{terminal-id}.json tasks/task-{taskid}.json`
4. If the rename succeeds: the terminal owns the task (it atomically replaced the file)
5. If the rename fails (another terminal already claimed it): try the next task

This works because `rename()` on most Unix filesystems is atomic — only one process can win the race.

## File Ownership Manifest

Before editing any file, a Hive member:
1. Reads `ownership/manifest.json`
2. If the file is owned by another terminal: skip it, pick a different task, or message the owner
3. If unowned: writes its terminal ID to the manifest for that path

On task completion, it releases ownership (removes its entries from the manifest).

This prevents the most common conflict: two agents both editing `src/auth.ts` and producing incompatible changes.

## Task Lifecycle

```
pending → claimed → in_progress → completed
                                → failed (with error)
```

Tasks are created by `/hive decompose [description]` which uses Claude to break a goal into parallel-safe work units and writes them to `tasks/`. A terminal running `/hive join` starts a loop: claim a task → work on it → mark complete → claim the next.

## Use Cases

**Parallel feature development**: One terminal handles frontend, one handles backend API, one handles tests. All coordinate through the Hive — no step-on-each-other file conflicts.

**Multi-session research**: Start a research Hive before a long task. One terminal does web research, one analyzes existing code, one drafts the implementation plan. Results collected in `results/`.

**Long-running tasks**: Start the Hive, close your laptop, reopen tomorrow. Terminals that join a running Hive pick up remaining tasks automatically.

## Subcommands

| Command | Action |
|---------|--------|
| `/hive create [name]` | Initialize a new Hive, write config.json |
| `/hive join` | Register as a member, start claiming tasks |
| `/hive status` | Show active members, pending/claimed/completed task counts |
| `/hive claim [task-id]` | Manually claim a specific task |
| `/hive complete [task-id]` | Mark a task done, write result |
| `/hive decompose [goal]` | Break a goal into parallel tasks |
| `/hive message [terminal] [text]` | Send a message to another terminal's inbox |
| `/hive leave` | Unregister, release owned files |

## Implementation

See: [`skills/multi-agent/hive.md`](../skills/multi-agent/hive.md)
