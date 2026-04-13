---
name: social-draft
description: Generate a complete content package for any topic across all major social platforms (X, Instagram, Facebook, Reddit, LinkedIn, YouTube, Threads). Drafts land in Typefully for X/LinkedIn/Threads. Includes a trust-gate system that auto-escalates posting autonomy as content is approved.
user_invocable: true
triggers:
  - /social-draft
  - "draft a post"
  - "create social content"
  - "write a post about"
  - "social media post"
  - "draft social"
  - "post about"
allowed-tools:
  - Read
  - Write
  - Bash
  - mcp__claude_ai_Typefully__typefully_list_social_sets
  - mcp__claude_ai_Typefully__typefully_create_draft
  - mcp__claude_ai_Typefully__typefully_list_tags
  - mcp__claude_ai_Typefully__typefully_create_tag
  - mcp__claude_ai_Typefully__typefully_get_queue
  - mcp__claude_ai_ClickUp__clickup_create_task
  - mcp__claude_ai_ClickUp__clickup_filter_tasks
---

# /social-draft — Multi-Platform Content Package Generator

Generate a complete, platform-adapted content package for any topic. One command → 7 platform variants → Typefully drafts → ClickUp tracking.

## Persona & Voice (adapt to your brand)

Before generating content, establish the voice you're writing in. Key questions to answer for your setup:

- Who are you? (role, expertise, perspective)
- What's your tone? (casual/professional, technical/accessible)
- What's your location/context?
- What words/phrases do you NEVER use?
- What are your PII rules? (full name vs first name only, specific location vs general, client names vs "[industry] client")

**Default voice rules (adapt these):**
- Casual, confident, zero corporate speak
- Hooks must stop the scroll — start with a bold claim, a surprising number, or a contrarian take
- Short sentences. Fragment sentences are fine.
- CTAs: simple question or insight, never "Drop a comment below!" energy
- Use specific examples and real numbers
- NEVER use: "game-changer", "revolutionary", "leverage", "ecosystem", "synergy", "deep dive", "at the end of the day"
- No emojis unless requested
- No hashtags in LinkedIn posts

## Step-by-Step Process

### Step 1: Get the topic

If called with arguments, use those as the topic.
If called with no arguments, ask: "What topic or angle do you want to draft content around?"

### Step 2: Check active campaign context

Read your active campaign file if you have one. If a campaign is active, incorporate the campaign theme into the angle.

### Step 3: Check content pillar for today

If you maintain a content pillar schedule, read it and identify today's theme. If the topic fits naturally, lean into it.

### Step 4: Check trust scores

Read your trust score file (see Trust System section below). For each platform, note which are at trust level ≥30 (auto-draft to Typefully without asking) vs level 0 (present for review first).

### Step 5: Generate platform variants

Generate all variants in a single pass. Present each clearly labeled:

**X post** (≤280 chars, punchy, hook in first line):
```
[generate]
```

**X thread option** (5-7 tweets if topic warrants depth):
```
Tweet 1/7: [hook]
Tweet 2/7: [point]
...
```

**LinkedIn post** (150-300 words, no hashtags, ends with question or insight):
```
[generate]
```

**Threads** (≤500 chars, conversational tone):
```
[generate]
```

**Instagram caption** (150 words max + 3-5 relevant hashtags + image prompt):
Caption: [generate]
Hashtags: #[1] #[2] #[3]
Image prompt for Replicate: [detailed visual description]

**Facebook post** (200-400 words, community-friendly, ends with a question):
```
[generate]
```

**Reddit post** (value-first, no self-promo feel):
Title: [generate — compelling, not clickbait]
Body: [generate — detailed, genuinely helpful]
Suggested subreddits: [pick 1-2 that fit]

**YouTube description** (if topic suits video):
Title: [generate — SEO-optimized]
Description: [2-3 paragraphs: hook + what you'll learn + CTA]
Tags: [10-15 tags]

### Step 6: Determine content type

Classify as one of: `daily_tip`, `tutorial`, `hot_take`, `product_promo`, `thread`, `reply`

### Step 7: Push drafts to Typefully

Call `typefully_list_social_sets` to get connected accounts and their IDs.

For each of X, LinkedIn, Threads that has a connected social set:
- Call `typefully_create_draft` with the platform variant
- Set `schedule_date: null` (leave as draft, not auto-scheduled)
- Add tag matching the content type

Present confirmation: "Drafts created in Typefully for [platforms]. Review at typefully.com."

### Step 8: Update trust scores on user action

After presenting all content, ask for feedback on each platform: (approve / approve-edit / reject / skip)

Update your trust score file accordingly:

- **Approve (no edits):** `score += 8`
- **Approve with edits:** `score += 3`
- **Reject:** `score = max(0, score − 15)`
- **Skip:** No change

Write the updated scores back to your trust file with a history entry.

### Step 9: Create tracking task (optional)

If you use ClickUp or another task tracker, create a task:
- Name: "Content: [topic] — [date]"
- Description: Content type, platforms, trust scores, approval status

### Step 10: Report

Summarize:
- Typefully drafts created for: [list]
- Platforms for manual posting: [list with copy-paste text]
- Trust score changes: [table]

## Trust System

The trust system tracks how often content for each platform/content-type gets approved without changes. Higher trust unlocks more automation.

**Trust file format** (`social-trust.json`):
```json
{
  "updated_at": "ISO timestamp",
  "platforms": {
    "x": {
      "daily_tip": { "score": 0, "history": [] },
      "tutorial": { "score": 0, "history": [] },
      "hot_take": { "score": 0, "history": [] },
      "product_promo": { "score": 0, "history": [] }
    },
    "linkedin": { ... },
    "threads": { ... }
  }
}
```

**Trust levels:**

| Score | Behavior |
|-------|----------|
| 0-29 | Present for explicit approval before Typefully draft |
| 30-49 | Auto-create Typefully draft (not scheduled), user reviews at their pace |
| 50-79 | Auto-schedule daily_tip, tutorial, reply; queue hot_take/product_promo |
| 80-94 | Auto-schedule all except product_promo and sensitive topics |
| 95-100 | Full autonomy |

## Content Type Classification

- `daily_tip` — short useful insight, no product pitch
- `tutorial` — how-to, step-by-step, actionable
- `hot_take` — opinion, contrarian view, prediction
- `product_promo` — mentions your product or services
- `thread` — multi-part X thread or LinkedIn carousel idea
- `reply` — response to someone else's post

## Setup Notes

- Create `social-trust.json` in your data directory before first use
- Create an active campaign file (`active-campaign.json`) if you want campaign integration
- Set up Typefully MCP with your API key for automatic draft creation
- Instagram/Facebook/Reddit/YouTube require manual posting — Typefully handles X, LinkedIn, Threads
- Never post directly without trust-gate clearance. At level 0, drafts only.
