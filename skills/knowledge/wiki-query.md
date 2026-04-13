---
name: wiki-query
description: Answer a question by searching the LLM Wiki first, then synthesizing from wiki pages with citations. Optionally files novel answers back into the wiki. Use when the user asks a question that might be answered by the knowledge wiki.
argument-hint: <question>
user_invocable: true
allowed-tools: ["Read", "Bash", "Glob", "Grep", "Write", "Edit"]
---

# Wiki Query

Answer a question using the LLM Wiki as the primary source.

## Paths

```
WIKI_ROOT=~/.claude/memory/03-Resources/llm-wiki
RAW=$WIKI_ROOT/raw
WIKI=$WIKI_ROOT/wiki
```

Adapt these paths to match where your knowledge wiki lives.

## Core Rule

**Always check `wiki/` before `raw/`.** The wiki is the distilled cache. Reading raw sources directly bypasses the synthesis work already done and bloats the context window.

## Workflow

### Step 1: Load the index

Read `$WIKI/wiki/index.md` — this tells you what pages exist and what topics they cover. Do this before any search.

### Step 2: Identify relevant pages

From the index and the question, list which wiki pages are likely relevant. Read them.

For keyword-based search (when the question is broad):
```bash
grep -ril "{keywords}" {your-wiki-root}/wiki/ 2>/dev/null
```

### Step 3: Synthesize the answer

From the wiki pages you read, synthesize a direct answer. Format:
- Lead with the answer (no preamble)
- Support with evidence from wiki pages, cited inline: `([[page-name]])`
- Include the original raw source citation where needed: `(source: raw/{subfolder}/filename.md)`

### Step 4: Assess completeness

Ask: is the answer complete based on wiki pages alone? If not:
1. Check if relevant raw sources exist that haven't been fully synthesized
2. If yes: read the raw source to fill gaps, then update the relevant wiki page (INGEST workflow)
3. If no: note the gap in the answer

**Never make up information** not in wiki or raw. Flag the gap explicitly.

### Step 5: File novel answers (optional)

If the synthesized answer represents new insight not already in the wiki:
- Offer to file it as a new wiki page or append to an existing one
- If the user agrees: write the page, update index.md, append to log.md
- Format: "This answer synthesizes X + Y in a way that's not yet explicit in the wiki. Want me to file it as `wiki/new-topic.md`?"

## Output Format

```
**Answer:** {direct answer}

**From wiki:**
- {key point} ([[page-name]])
- {key point} ([[page-name]])

**Raw source if needed:**
- (source: raw/{subfolder}/filename.md)

**Gaps:** {any areas where the wiki doesn't fully cover the question}
```

## Out of Scope

If the question is about a topic not covered in your wiki, answer from general knowledge or other project documentation — not the wiki. Be explicit about which source you're drawing from.
