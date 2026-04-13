---
name: scaffold-claude-md
description: Generate a CLAUDE.md for a repository by inspecting its stack, structure, and git history. Usage: /scaffold-claude-md [path] — defaults to current directory.
allowed_tools:
  - Read
  - Write
  - Bash
  - Glob
---

# Scaffold CLAUDE.md

Generate a CLAUDE.md file for the target repository. Do NOT overwrite an existing CLAUDE.md without user confirmation.

## Steps

### 1. Determine target path
- If an argument was provided, resolve it (expand `~` to home directory)
- Otherwise use the current working directory

### 2. Check for existing CLAUDE.md
```bash
ls {path}/CLAUDE.md 2>/dev/null
```
If one exists, ask the user whether to overwrite before continuing.

### 3. Detect stack
Read these files if they exist:
```bash
cat {path}/package.json 2>/dev/null
cat {path}/pyproject.toml 2>/dev/null
cat {path}/Cargo.toml 2>/dev/null
cat {path}/go.mod 2>/dev/null
head -40 {path}/Makefile 2>/dev/null
```

### 4. Inspect structure
```bash
ls -la {path}
ls {path}/src {path}/app {path}/lib {path}/packages 2>/dev/null
```

### 5. Check git info
```bash
cd {path} && git log --oneline -10 2>/dev/null
cd {path} && git remote get-url origin 2>/dev/null
```

### 6. Generate CLAUDE.md

Use the information gathered to fill in this template. Only include sections where you found real data — omit sections for which you found nothing.

```markdown
# {project name} — {one-line description}

## Tech Stack
- **{layer}**: {technology + version if relevant}

## Commands
\`\`\`bash
# development
{dev command}

# build
{build command}

# test
{test command}
\`\`\`

## Directory Structure
{list only key directories that exist, with one-line descriptions}

## Rules
- {inferred constraints: TypeScript strict mode, bun vs npm, monorepo structure, etc.}
- {deployment target if detectable}
```

### 7. Write and confirm
Write to `{path}/CLAUDE.md`, then read back the first 10 lines to confirm.
