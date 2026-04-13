---
name: swarm
description: Choose the right agent dispatch pattern (simple parallel / orchestrator / hive) and generate agent prompts
allowed-tools: ["Read", "Glob", "Grep", "Agent", "Task", "TaskCreate", "TaskList"]
user_invocable: true
---

# Agent Swarm Dispatcher

## This is a RIGID skill — follow it exactly.

Choose the right dispatch tier, generate isolated agent prompts, and integrate results. Prevents #1 friction source: wrong approach from missing constraints.

---

## Tier Decision Tree

```
Have 3+ independent work units?
  └─ YES → Are they long-running or multi-terminal?
        ├─ YES → Hive (file-based queue, multi-terminal)
        └─ NO  → Need sequential specialist phases (explore→build→verify→deploy)?
              ├─ YES → Orchestrator (single lead + specialists)
              └─ NO  → Simple parallel Agent dispatch ← DEFAULT
  └─ NO (1-2 units) → Inline work (no dispatch overhead)
```

**Default: Simple parallel.** Only escalate if the criteria above are met.

---

## Tier 1: Simple Parallel Agent Dispatch

**Use when:** 3+ independent tasks in a single terminal session.

**Template:**
```
Launch agents in parallel (single message, multiple Agent tool calls):

Agent 1 — [role: Explore/builder/verifier/etc.]
Task: [specific, bounded task]
Scope: [exact files/dirs to touch]
Constraints: Do NOT modify .env, shared config, or files outside scope.
Return: [exact expected output format]

Agent 2 — [role]
Task: ...
```

**Agent isolation rules:**
- Each agent gets only the context it needs — no session history inheritance
- Parent constructs full context in the prompt (file paths, relevant code snippets, error messages)
- No agent writes to .env, API credentials, or shared config — flag these for user
- Conflicts: if two agents might touch the same file, assign file ownership to one

**Integration after agents return:**
1. Read each agent's summary
2. Check for file conflicts (same file edited by 2 agents?)
3. Run full test suite / tsc --noEmit
4. If conflicts: resolve manually, then re-run

---

## Tier 2: Orchestrator Pattern

**Use when:** 3+ sequential phases where each phase's output feeds the next.

**Examples:** explore→plan→build→verify→deploy | audit→fix→test→PR

**How to invoke:**
```
Use Agent tool with subagent_type="orchestrator":
- Provide full context: current codebase state, goal, constraints
- List the phases explicitly
- Orchestrator will spawn builder/verifier/deployer as needed
```

**When orchestrator is appropriate:**
- Feature implementation spanning 5+ files
- Refactoring with architectural decisions
- Build-test-deploy workflows with conditional logic

---

## Tier 3: Hive (Multi-Terminal)

**Use when:** Work must persist across sessions, or spans multiple terminal windows.

**Rarely needed.** Only use when:
- Background workers need to run while you work on something else
- Tasks take >30min and you want to context-switch
- Multiple humans are collaborating via separate terminals

**How to invoke:** `/hive init [name]` then `/hive dispatch [task]`

---

## Workflow When User Says "Let's build X"

1. **Decompose** the task into independent units
2. **Count** them — 1-2 units = inline, 3+ = dispatch
3. **Check for dependencies** — if unit B requires unit A's output, they're sequential (Orchestrator), not parallel
4. **Choose tier** using the decision tree above
5. **Generate agent prompts** using the templates below
6. **Dispatch** all parallel agents in a single message (one tool call per agent)
7. **Integrate** results after all agents return

---

## Agent Prompt Template (copy-adapt for each agent)

```markdown
You are a [role] agent. Your task is isolated — do not perform work outside your defined scope.

**Task:** [specific, single-responsibility task]

**Scope:**
- Files you may read: [list]
- Files you may edit: [list]
- Files you must NOT touch: .env, shared config, files owned by other agents

**Context:**
[paste only the relevant code snippets, error messages, or facts this agent needs]

**Constraints:**
- [specific constraint 1]
- [specific constraint 2]
- Do NOT over-engineer. Implement the simplest solution that satisfies the task.

**Expected output:**
[Exact format: summary of changes, list of files modified, test results, or "stuck: [reason]"]
```

---

## Common Anti-Patterns (avoid these)

| Anti-pattern | Correct approach |
|---|---|
| "Fix all the tests" | One agent per failing test file/domain |
| Agent reads your session history | Parent constructs all needed context in prompt |
| Agent modifies .env during parallel sprint | Flag for user, skip the change |
| Using Hive for a 2-hour single-session build | Use simple parallel dispatch |
| Orchestrator for a 2-file change | Inline work, no dispatch needed |
