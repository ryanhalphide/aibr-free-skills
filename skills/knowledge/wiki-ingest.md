---
name: wiki-ingest
description: Ingest a new source into the LLM Wiki. Adds to raw/, synthesizes into wiki/, updates index.md and log.md. Use when the user provides a URL, file path, or @handle to add to the knowledge wiki.
argument-hint: <url|path|@handle> [--subfolder name]
user_invocable: true
allowed-tools: ["Bash", "Read", "Write", "Edit", "WebFetch", "Glob", "Grep", "Agent", "Skill"]
---

# Wiki Ingest

Add a new source to the LLM Wiki and synthesize it into the wiki layer.

## Paths

```
WIKI_ROOT=~/.claude/memory/03-Resources/llm-wiki
RAW=$WIKI_ROOT/raw
WIKI=$WIKI_ROOT/wiki
```

Adapt these paths to match where your knowledge wiki lives. The structure (raw/ + wiki/) is what matters.

## Argument Parsing

From `$ARGUMENTS`, extract:
- **target**: A URL, local file path, or `@username` (social handle)
- **--subfolder name**: Override the default raw/ subfolder (auto-detected otherwise)

Auto-detect subfolder:
- `@username` or handle-style URL → `{username}/`
- Known author/source domains → `{author-name}/`
- Everything else → `other/`

## Workflow

### Step 1: Acquire the source

**If target is a URL:**
- WebFetch the URL
- Save cleaned content (no HTML nav, no ads) as a markdown file in `$RAW/{subfolder}/`
- Filename: `kebab-case-title-YYYY-MM-DD.md`

**If target is a local file path:**
- Read the file
- Copy it to `$RAW/{subfolder}/` with appropriate frontmatter added

**If target is a `@username` (social handle):**
- Attempt to fetch the handle's public page or profile
- Extract whatever is publicly accessible
- Note the source type in frontmatter as `reel-extraction` or `social-profile`

### Step 2: Frontmatter

Every file added to `raw/` must have:
```yaml
---
source: <url or original path>
author: <name if known>
date: YYYY-MM or YYYY-MM-DD
type: primary-source | secondary-source | reel-extraction
ingested: YYYY-MM-DD
---
```

### Step 3: Determine wiki impact

Read the new source(s). Ask:
1. Which existing `wiki/` pages does this source add to or update?
2. Does this source warrant a new dedicated `wiki/*.md` page?

Rules:
- Update existing if the new content is ≤ 30% new information vs. what's already there
- Create new if the source covers a distinct topic not yet in the wiki

### Step 4: Write/update wiki pages

For each affected wiki page:
- Add new content, clearly attributed: `(source: raw/{subfolder}/filename.md)`
- Update frontmatter: `updated: YYYY-MM-DD`, add new source to `sources:` list
- If creating new page, include standard frontmatter + Related section with wikilinks

### Step 5: Update index.md

Open `$WIKI/index.md` and:
- Add the new page to the appropriate topic group (if new page created)
- Update "Pages Pending" section
- Update `updated:` frontmatter

### Step 6: Append to log.md

```
## YYYY-MM-DD — {one-line description}

**Action:** Ingested {source title}
**Source added:** raw/{subfolder}/{filename}
**Wiki pages updated:** {list}
**New pages created:** {list or none}
```

### Step 7: Commit the vault

```bash
cd {your-wiki-root} && git add -A && git commit -m "wiki: ingest {source title}"
```

## Edge Cases

| Situation | Action |
|-----------|--------|
| Source behind paywall | Note in frontmatter `access: paywalled`, ingest what's publicly visible |
| Source not in whitelist | Flag to user before ingesting: "This source doesn't match any whitelist axis — ingest anyway?" |
| Duplicate source (already in raw/) | Check content; skip if identical, update with `updated:` frontmatter if changed |
| Private profile or login required | Inform user: log into the platform manually, then retry or provide exported content |
