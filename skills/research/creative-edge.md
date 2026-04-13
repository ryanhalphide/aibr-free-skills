---
name: creative-edge
description: "Outside-the-box creative brainstorming for finding untapped edges, unconventional approaches, and ideas nobody else is thinking of. Use when the user says '/creative-edge', 'think outside the box', 'what are we missing', 'creative ideas', 'unconventional approach', 'find an edge', 'what would a genius do', 'surprise me', 'innovative solutions', or wants to explore wild ideas before filtering them down to actionable ones. Combines web research of forums/communities/papers with structured creative thinking to surface non-obvious opportunities."
---

# Creative Edge: Outside-the-Box Thinking

A structured creative process for finding ideas nobody else is pursuing. Combines divergent thinking, forum/community research, and rapid feasibility filtering.

The goal isn't to be creative for creativity's sake — it's to find **real edges** that are hiding in plain sight because everyone is looking at the same conventional approaches.

## Why This Exists

Most optimization is incremental — tune a parameter, add a feature, fix a bug. But the biggest gains come from **category jumps** — doing something fundamentally different that your competitors aren't even considering.

The pattern: research broadly across unconventional sources, generate wild ideas without filtering, THEN ruthlessly filter for feasibility and impact.

## The Process

### Phase 1: Divergent Research (cast the widest net)

Search unconventional sources for ideas others miss:

1. **Forum mining** — Search Reddit, Hacker News, niche Discord/Telegram groups, Stack Overflow for people solving adjacent problems in creative ways
   - Search queries: `"nobody is doing" + [domain]`, `"unconventional" + [domain]`, `"why doesn't anyone" + [domain]`
   - Look for complaints (unmet needs), hacks (creative workarounds), and failed attempts (learning what doesn't work tells you what might)

2. **Academic papers** — Search arXiv, Google Scholar for recent papers with novel approaches
   - Focus on papers from the last 6 months that combine two fields (e.g., NLP + trading, game theory + pricing)
   - Look for "we found that surprisingly..." statements — those are where edges hide

3. **Adjacent industries** — What are people in completely different fields doing that could apply?
   - Sports betting → trading (odds making, line movement)
   - Gaming → engagement (reward loops, dopamine cycles)
   - Supply chain → logistics (just-in-time, demand forecasting)
   - Biology → algorithms (genetic algorithms, swarm intelligence)

4. **Contrarian signals** — What is everyone SURE about that might be wrong?
   - "Everyone knows X doesn't work" → test X with new tools/data
   - "The market is efficient" → find specific micro-inefficiencies
   - "You can't beat index funds" → find the niche where you can

### Phase 2: Wild Ideation (no filter, quantity over quality)

Generate 20+ ideas without judging feasibility. Use these prompts:

- "What if we could [impossible thing]? What's the closest achievable version?"
- "What data source exists that nobody is using for [this purpose]?"
- "What would a $10B company do with our infrastructure?"
- "What would a 16-year-old with no preconceptions try?"
- "What's the laziest possible way to achieve [goal]?"
- "What if we combined [thing A from domain X] with [thing B from domain Y]?"
- "What would we build if we had unlimited API access to every service?"
- "What's the opposite of what everyone else is doing?"

### Phase 3: Feasibility Filter (ruthless triage)

Score each idea on three axes:

| Axis | Question | Score 1-5 |
|------|----------|-----------|
| **Edge** | Does this give us information/speed others don't have? | |
| **Effort** | Can we build an MVP in <4 hours? | |
| **Scalability** | Does this get better with more data/time/capital? | |

Kill anything scoring < 8 total. The top 3-5 survive.

### Phase 4: Rapid Prototype

For each survivor:
1. Build the simplest possible version (1-2 hours max)
2. Run it against real data for 24 hours
3. Measure the metric that matters
4. Keep or kill based on data, not intuition

### Phase 5: AutoResearch Loop

For survivors that show promise, run them through the Karpathy Loop (`/auto-research`) to optimize parameters. The creative process finds the WHAT; AutoResearch finds the optimal HOW.

## Idea Templates by Domain

### Trading / Finance
- **Whale mirroring**: Track large wallet movements on-chain and follow the direction — if large holders are accumulating, the trend is likely up
- **Liquidation cascade prediction**: Monitor funding rates + open interest; when leverage is extreme, a small move triggers cascading liquidations = volatility = opportunity
- **Cross-exchange spread**: Same asset priced differently on different venues; arbitrage the spread
- **News velocity**: Not what the news says, but how FAST it spreads. Measure propagation speed across platforms as a signal
- **Anti-correlation harvesting**: Find pairs that move opposite to each other; trade the spread
- **Social media velocity**: Track rate-of-change of mentions (not absolute count) as a leading indicator
- **Calendar patterns**: Exploit predictable human behavior (end-of-month rebalancing, options expiry, tax loss harvesting)

### Software / Product
- **Workflow mining**: Watch what users actually do (not what they say they do) and automate the most common sequence
- **Error-driven features**: The most common error messages reveal the most needed features
- **Adjacent tool integration**: Connect two tools that should talk but don't
- **Upside-down product**: Take a feature everyone charges for and make it free; charge for something nobody thought was valuable

### Content / Marketing
- **Contrarian content**: Write the opposite of what everyone is saying; it gets 10x more engagement
- **Micro-audience**: Find a group of 100 people with an underserved need; serve them perfectly
- **Format arbitrage**: Take content from one format (podcast) and adapt to another (interactive tool)

## Key Principles

1. **Research breadth beats depth** — scan 50 sources shallowly before going deep on 3
2. **Quantity breeds quality** — generate 20 bad ideas to find 2 good ones
3. **Adjacent fields hold the best ideas** — the best ideas in one domain often come from another
4. **Test fast, kill faster** — 4-hour MVP, 24-hour validation, then decide
5. **The obvious ideas are already priced in** — if it's easy to think of, someone's already doing it
6. **Contrarian + correct = edge** — you need to be right AND different
7. **Data > intuition** — always run the experiment, never trust the theory

## After Brainstorming

Present findings as:
```
CREATIVE EDGE REPORT
═══════════════════

Top 3 Ideas (scored):
1. [Name] — Edge:X Effort:X Scale:X = Total:XX
   What: [one sentence]
   Why nobody's doing it: [one sentence]
   MVP: [what to build in 4 hours]

2. ...
3. ...

Killed Ideas (for reference):
- [idea]: killed because [reason]

Next Step: Build MVP of #1, run for 24h, measure [metric]
```
