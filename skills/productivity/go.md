---
name: go
description: Universal session-start command — smart context detection, zero friction, maximum velocity. Detects morning vs active session vs project switch and does the right thing automatically.
priority: high
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - Skill
  - Write
---

<objective>
ONE command to rule them all.

`/go` detects context and does the right thing:
- Morning? Shows yesterday's work, today's priorities
- Active session? Resumes where you left off
- Argument provided? Switches to that project
- Nothing clear? Shows recent projects to pick

Zero friction. Maximum velocity. Just go.
</objective>

## Working Directory Rule
ALWAYS: When switching to a project context, the FIRST action is to set the working directory to the project repo using an inline `cd ~/Code/...` in any bash commands. Never run project commands from `~`.

<process>

<step name="detect_context">
**Instantly analyze situation:**

```bash
SESSION_FILE=~/.claude/.current-work-session.json
HAS_SESSION=$([[ -f "$SESSION_FILE" ]] && echo true || echo false)
IS_MORNING=$([[ $(date +%H) -lt 12 ]] && echo true || echo false)
CWD=$(pwd)
PROJECT=$(basename "$CWD")
```

Decision tree:
1. **Argument given** (`/go my-project`) → Switch to that project
2. **Active session exists** → Resume it
3. **Morning + no session** → Show morning briefing
4. **Known project directory** → Load that project
5. **Nothing clear** → Show recent projects menu
</step>

<step name="morning_briefing">
**If morning (before noon) and no active session:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Good morning! Here's your context:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Last session: ${PROJECT} (${TIME_AGO})
  Last action: ${LAST_SUMMARY}

  Today's priorities:
  1. ${PRIORITY_1}
  2. ${PRIORITY_2}

  Ready? Continue from last position or type a project name.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
</step>

<step name="resume_session">
**If active session exists:**

Read `~/.claude/.current-work-session.json`:
```json
{
  "project": "my-project",
  "directory": "/path/to/project",
  "next_action": "Implement JWT refresh",
  "last_position": "src/auth.ts:142",
  "timestamp": "2026-01-17T10:00:00Z"
}
```

Display:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Resuming: ${PROJECT}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Next: ${NEXT_ACTION}
  Last file: ${LAST_POSITION}

  [Continuing...]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then:
1. Navigate to directory
2. Show git status and recent commits
3. Offer to execute next planned action
</step>

<step name="switch_project">
**If argument provided (`/go my-project`):**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Switching to: ${PROJECT}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Saved current session
  Loading ${PROJECT} context...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Set working directory to the project root, then show project status and next steps.

**Per-project working directory — set this BEFORE any other action:**

Your project aliases live in your session state file. Define them by adding entries to `~/.claude/.current-work-session.json` or maintain a `~/.claude/project-registry.json`. Example structure:

```json
{
  "projects": {
    "my-app": "~/Code/my-app/",
    "my-api": "~/Code/my-api/",
    "my-blog": "~/Code/Personal/blog/"
  }
}
```

`/go my-app` → set cwd to `~/Code/my-app/` before any work.
</step>

<step name="show_menu">
**If no clear context:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Where to?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Recent:
  1. [project-name] (2h ago) - last action
  2. [project-name] (yesterday)
  3. [project-name] (3d ago)

  [1-3] or project name:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Populate the list from `~/.claude/.current-work-session.json` history.
</step>

<step name="save_state">
**Always save session state:**

After any `/go` action, update `~/.claude/.current-work-session.json`:
```json
{
  "project": "${PROJECT}",
  "directory": "${CWD}",
  "next_action": "${NEXT}",
  "timestamp": "${NOW}"
}
```
</step>

</process>

<shortcuts>

## Flags
```bash
/go            # Smart detection
/go my-project # Switch to named project
/go .          # Current directory
/go --status   # Show status only, don't execute
/go --fresh    # Ignore session, start fresh
/go --end      # End current session, save state
```

</shortcuts>

<success_criteria>

- Detects all contexts correctly (morning, session, menu)
- Resumes sessions seamlessly with correct working directory
- Switches projects without requiring extra commands
- Saves state automatically after every invocation
- Works with just `/go` — no arguments needed

</success_criteria>
