---
name: wiki-lint
description: Health-check the LLM Wiki for structural issues — orphan pages, stale content, missing citations, contradictions, index drift, and unsynthesized raw sources. Writes a timestamped report to lint/. Does NOT auto-fix. Use weekly or when the wiki feels stale.
argument-hint: (no arguments)
user_invocable: true
allowed-tools: ["Read", "Bash", "Write", "Glob", "Grep"]
---

# Wiki Lint

Health-check the LLM Wiki. Surface issues for human review. Never auto-fix.

## Paths

```
WIKI_ROOT={your-wiki-root}
RAW=$WIKI_ROOT/raw
WIKI=$WIKI_ROOT/wiki
LINT=$WIKI_ROOT/lint
DATE=$(date +%Y-%m-%d)
REPORT=$LINT/$DATE-lint.md
```

## Checks

### 1. Orphan pages
Pages in `wiki/` not listed in `wiki/index.md`.
```bash
ls {your-wiki-root}/wiki/*.md | grep -v "index.md\|log.md"
# Then check each against index.md
```

### 2. Stale pages
Wiki pages with `updated:` frontmatter > 30 days ago AND no recent log.md entry.
```bash
grep -r "updated:" {your-wiki-root}/wiki/ | grep -v "index\|log"
```

### 3. Missing citations
Wiki pages that make factual claims but have no `(source: raw/...)` citation.
Look for: paragraphs with specific claims (dates, quotes, statistics) that lack a source reference.

### 4. Contradictions
Same named concept defined differently across wiki pages.
Key things to check: core terminology that appears in multiple pages where definitions might drift.
```bash
grep -r "{key-term}" {your-wiki-root}/wiki/
```

### 5. Index drift
Wiki pages that exist but aren't in `index.md`.
Also: pages listed in `index.md` that no longer exist.

### 6. Unsynthesized raw sources
Files in `raw/` with no corresponding wiki page or citation.
```bash
ls {your-wiki-root}/raw/**/*.md 2>/dev/null
# Cross-reference against sources: frontmatter in wiki/*.md
```

### 7. Log completeness
Wiki pages with `updated:` timestamps that have NO corresponding log.md entry.
Every edit should produce a log entry.

## Report Format

Write to `$REPORT`:

```markdown
---
type: lint-report
date: YYYY-MM-DD
issues-found: N
---

# Wiki Lint Report — YYYY-MM-DD

## Summary
- Total wiki pages: N
- Total raw sources: N
- Issues found: N (M critical, K warnings)

## Critical Issues (require action)

### Contradictions
- **{concept}**: defined as "{A}" in [[page1]] but "{B}" in [[page2]]

### Missing citations
- **[[page-name]]**: claims "{quote}" with no source reference

## Warnings (review when convenient)

### Orphan pages (not in index)
- `wiki/filename.md` — not listed in index.md

### Stale pages (>30 days, no log entry)
- `wiki/filename.md` — last updated YYYY-MM-DD

### Unsynthesized raw sources
- `raw/subfolder/filename.md` — no wiki page cites this source

### Index drift
- Listed in index.md but file missing: {filename}

## Recommended Actions
1. {highest priority fix}
2. {second priority fix}
...

## No Action Needed
- {list of checks that passed cleanly}
```

## After Writing the Report

```bash
cd {your-wiki-root} && git add -A && git commit -m "wiki: lint report {date}"
```

Report to the user:
- How many issues were found
- The report path: `lint/{date}-lint.md`
- The highest-priority issue (if any critical ones exist)

**Do not fix anything.** The report is for human review. If the user says "fix the orphan pages," THEN run the targeted fixes — but not before.
