---
name: cost-track
description: Estimate token costs across recent Claude Code sessions, identify high-cost patterns, and get specific recommendations to reduce spend
allowed-tools: ["Read", "Bash", "Glob"]
user_invocable: true
argument-hint: "[--days N] [--session session-id]"
---

# /cost-track — Token Cost Estimator

Estimates token usage across recent sessions and identifies the patterns driving the most cost. All estimates are approximate — actual costs depend on your plan and exact token counts.

## Step 1: Parse Arguments

- `--days N`: Analyze sessions from the last N days (default: 7)
- `--session [id]`: Analyze a single specific session

## Step 2: Find Session Files

```bash
# Locate session transcript files
find ~/.claude/projects/ -name "*.jsonl" -newer ~/.claude/projects/ -mtime -7 2>/dev/null | sort -t/ -k1 | head -20
# Also check conversation archives if present
find ~/.config/superpowers/conversation-archive/ -name "*.jsonl" -mtime -7 2>/dev/null | head -10
```

## Step 3: Estimate Token Usage Per Session

For each session file found:

```bash
# Rough token estimate: file size / 4 bytes per token (very approximate)
wc -c session-file.jsonl | awk '{print int($1/4), "tokens (~"int($1/4/1000)"K)"}'

# More accurate: count lines (each line is a message/event)
wc -l session-file.jsonl
```

Token cost approximations (as of 2026):
- Claude Opus: ~$15/M input, ~$75/M output
- Claude Sonnet: ~$3/M input, ~$15/M output  
- Claude Haiku: ~$0.25/M input, ~$1.25/M output

**Note**: These are rough estimates. Check Anthropic's current pricing for exact rates.

## Step 4: Identify High-Cost Patterns

Scan session content for indicators:

**High token consumption patterns:**
- Large file reads (reading files >500 lines repeatedly)
- Many agent dispatches without Haiku routing (each agent gets a full context copy)
- Long exploration chains without compaction
- Repeated context over many sessions (same CLAUDE.md re-read every time)
- Missing memory system (rediscovering the same things repeatedly)

```bash
# Count tool calls in a session (proxy for cost)
grep -c '"type":"tool_use"' session-file.jsonl 2>/dev/null || echo "Can't parse"

# Look for large file reads
grep '"name":"Read"' session-file.jsonl | grep -o '"limit":[0-9]*' | sort -t: -k2 -n | tail -5
```

## Step 5: Model Distribution Estimate

If model names are logged in session files:
```bash
grep -o '"model":"[^"]*"' session-file.jsonl | sort | uniq -c | sort -rn
```

Estimate: What percentage of operations went to each tier?
- Opus %: [estimated]
- Sonnet %: [estimated]  
- Haiku %: [estimated]

**Routing opportunity**: If >50% of operations are Opus and many are search/read tasks, routing those to Haiku could cut costs significantly.

## Step 6: Generate Cost Report

Output:

```
## Token Cost Estimate — Last 7 Days

Sessions analyzed: [N]
Total estimated tokens: ~[X]K
Estimated cost range: $[low] – $[high]
  (range reflects uncertainty in input/output split and exact pricing)

## Top Cost Drivers

1. [Pattern] — [% of estimated cost]
   Reduction: [specific change] → estimated [X]% savings

2. [Pattern] — [% of estimated cost]
   Reduction: [specific change]

3. [Pattern] — [% of estimated cost]
   Reduction: [specific change]

## Model Distribution (estimated)
- Opus: [X]% of operations
- Sonnet: [X]% of operations
- Haiku: [X]% of operations

Routing opportunity: [X] Opus operations appear to be search/read tasks
that could route to Haiku → estimated [Y]% cost reduction.

## Top 5 Recommendations

1. [Specific action with expected savings]
2. ...
```

Note: All figures are estimates. Use them to identify relative patterns, not as exact billing numbers.
