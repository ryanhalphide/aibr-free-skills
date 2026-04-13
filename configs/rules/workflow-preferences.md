---
globs: ["**"]
---

# Workflow Preferences

## Phase Discipline
- **Discovery is read-only**: no writes to target systems during discovery phase
- **Planning produces docs**: every plan must be written to a file before execution begins
- **Always gate-check**: run `/gate-check` before transitioning between phases

## Documentation First
- Every assumption must be logged with `/assumption` before proceeding
- Every external source must be logged with `/source-log`
- Every session must end with `/session-end`

## Tool Hierarchy
- CLI > MCP tools > Browser automation > Manual steps
- Never ask the user to open a browser if an MCP tool can handle it
- Never ask the user to run a command that Claude can run

## Agent Delegation
- Use `/delegate @profile` for specialized sub-tasks
- Each agent works in its defined scope — no cross-boundary actions
- Agents report findings before Claude acts on them
