---
name: social-campaign
description: Create and manage multi-day social media campaigns. Generates a day-by-day content calendar with theme-cohesive posts across all platforms, Typefully batch drafts, ClickUp milestone tasks, and Google Calendar events.
user_invocable: true
triggers:
  - /social-campaign
  - "create a campaign"
  - "plan a campaign"
  - "multi-day campaign"
  - "launch campaign"
  - "campaign calendar"
allowed-tools:
  - Read
  - Write
  - Bash
  - mcp__claude_ai_Typefully__typefully_list_social_sets
  - mcp__claude_ai_Typefully__typefully_create_draft
  - mcp__claude_ai_Typefully__typefully_list_tags
  - mcp__claude_ai_Typefully__typefully_create_tag
  - mcp__claude_ai_ClickUp__clickup_create_task
  - mcp__claude_ai_ClickUp__clickup_filter_tasks
  - mcp__claude_ai_Google_Calendar__gcal_create_event
  - mcp__claude_ai_Google_Calendar__gcal_list_calendars
---

# /social-campaign — Multi-Day Campaign Planner

Turn a campaign theme into a complete content calendar — daily post briefs, Typefully drafts, ClickUp milestone tasks, and Google Calendar events.

## Voice & Persona

Apply the same voice rules as `/social-draft`. Establish your persona before generating content — see that skill for the full voice setup guide.

## Step-by-Step Process

### Step 1: Get campaign parameters

If called WITH arguments, parse them as: `<theme> [--days N] [--start YYYY-MM-DD] [--platforms x,linkedin,threads]`

If called with NO arguments, ask:
1. "What's the campaign theme or goal? (e.g., 'launch product beta', 'content about my tech stack', 'weekly tutorial series')"
2. "How many days? (default: 5)"
3. "Start date? (default: next Monday)"
4. "Any platforms to exclude? (default: all 7)"

Collect all four before proceeding.

### Step 2: Check active campaign

Read your `active-campaign.json`. If `active: true`, show the current campaign name and ask: "There's already an active campaign ([name]). Replace it, or keep both and append?"

### Step 3: Build the campaign arc

Based on the theme and duration, design a content arc — a narrative progression across days:

**For a 5-day campaign (standard):**
- Day 1: Hook / Problem Setup — introduce the pain point or tension
- Day 2: Behind the Scenes — show the process/system
- Day 3: Proof / Results — concrete numbers or outcomes
- Day 4: Tutorial / How-to — actionable takeaway
- Day 5: CTA / Offer — soft close, what to do next

**For a 3-day campaign:**
- Day 1: Problem + Hook
- Day 2: Process + Proof
- Day 3: Takeaway + CTA

**For a 7-day campaign:**
- Day 1: Hook, Day 2: Problem depth, Day 3: Behind the Scenes, Day 4: Social proof, Day 5: Tutorial, Day 6: Hot take / controversy, Day 7: CTA wrap-up

For other lengths, extrapolate a logical narrative arc.

Present the arc to the user: "Here's the story I'd tell across [N] days:" followed by the day-by-day breakdown. Ask: "Does this arc work, or want to adjust any day?"

Proceed only after arc approval.

### Step 4: Check trust scores

Read your trust score file. Note which platforms are at trust ≥ 30 (auto-draft without asking) vs 0 (present for approval).

### Step 5: Generate all campaign content

Generate all days × all platforms in one pass. Present clearly labeled:

---
**DAY [N] — [Arc role] — [Date YYYY-MM-DD]**

**Campaign angle:** [1-sentence brief for this day]

**X post** (≤280 chars):
```
[generate]
```

**X thread option** (5-7 tweets if topic warrants depth):
```
Tweet 1/5: [hook]
...
```

**LinkedIn post** (150-300 words, no hashtags):
```
[generate]
```

**Threads** (≤500 chars):
```
[generate]
```

**Instagram caption** (150 words max):
Caption: [generate]
Hashtags: #[1] #[2] #[3]
Image prompt: [visual description]

**Facebook post** (200-400 words, community-friendly):
```
[generate]
```

**Reddit post** (value-first, organic contribution):
Title: [generate]
Body: [generate]
Suggested subreddits: [1-2 relevant]
---

Repeat for each day.

### Step 6: User reviews content

Present the full calendar. Ask: "Any days or platforms you want to revise before I push to Typefully?"

Make any requested edits, then proceed.

### Step 7: Write campaign state to active-campaign.json

Write `active-campaign.json` with the full campaign definition:

```json
{
  "active": true,
  "campaign": {
    "id": "campaign-[theme-slug]-[start-date]",
    "theme": "[campaign theme]",
    "arc_description": "[brief arc summary]",
    "start_date": "YYYY-MM-DD",
    "end_date": "YYYY-MM-DD",
    "platforms": ["x", "linkedin", "threads", "instagram", "facebook", "reddit", "youtube"],
    "days": [
      {
        "day": 1,
        "date": "YYYY-MM-DD",
        "arc_role": "Hook / Problem Setup",
        "content_type": "hot_take",
        "brief": "[1-sentence angle for the day]",
        "posted": false,
        "drafts_created": false
      }
    ],
    "created_at": "[ISO timestamp]",
    "clickup_task_ids": [],
    "gcal_event_ids": []
  }
}
```

### Step 8: Push Typefully drafts

Call `typefully_list_social_sets` to get account IDs.

For each day × each Typefully-connected platform (X, LinkedIn, Threads):
- Call `typefully_create_draft` with the platform variant
- Set `schedule_date: null` (draft only)
- Add tag matching the campaign theme (create if needed with `typefully_create_tag`)

After all drafts are created:
- Update the day in `active-campaign.json`: set `drafts_created: true`
- Report count: "Created [N] Typefully drafts across [platforms]."

### Step 9: Create ClickUp campaign milestone task

Call `clickup_create_task`:
- Name: "Campaign: [theme] — [start_date] to [end_date]"
- Description: Arc summary, day-by-day breakdown, platform list, Typefully draft status
- Status: "in progress"

Create one sub-task per day:
- Name: "Day [N]: [arc role] — [date]"
- Description: brief + platforms + content_type

Store returned task IDs in `active-campaign.json` → `clickup_task_ids`.

### Step 10: Create Google Calendar events

Call `gcal_list_calendars` to find the right calendar.

For each day of the campaign:
- Call `gcal_create_event`:
  - Title: "Social: [campaign theme] Day [N] — [arc role]"
  - Date: campaign day (all-day event)
  - Description: content type + platform list + brief

Store returned event IDs in `active-campaign.json` → `gcal_event_ids`.

### Step 11: Report

```
CAMPAIGN CREATED
Theme: [theme]
Duration: [N] days ([start] → [end])
Arc: [brief arc description]

TYPEFULLY
  Created [N] drafts for X, LinkedIn, Threads
  Review and schedule at typefully.com

MANUAL POSTING NEEDED
  Instagram, Facebook, Reddit, YouTube — copy-paste text above

CLICKUP
  Milestone task: [link if returned]
  [N] daily sub-tasks created

GOOGLE CALENDAR
  [N] events added to [calendar name]

ACTIVE CAMPAIGN
  active-campaign.json updated
  To deactivate: /social-campaign end
  To check status: /social-campaign status
```

## Campaign Management Commands

**`/social-campaign status`** — show current campaign, how many days posted, what's remaining

**`/social-campaign end`** — set `active: false` in active-campaign.json, ask if ClickUp tasks should be closed

**`/social-campaign pause`** — set `active: false` without clearing the campaign (resume later)

**`/social-campaign resume`** — set `active: true` on the existing campaign

**`/social-campaign mark-posted [day N] [platform]`** — mark a day's post as sent

## How This Integrates With /social-draft

When `/social-draft` runs while a campaign is active, it:
1. Finds today's campaign day brief
2. Uses the campaign's content_type for trust scoring
3. Incorporates the campaign angle into all platform variants

This ensures every piece of content during an active campaign reinforces the same message arc.

## Content Arc Templates

Use these as starting points:

**Product Launch arc:** Tease → Behind the build → Why it solves X → How it works → Launch day CTA

**Value Prop arc:** Common mistake → The real problem → What actually works → Proof → How to get it

**Education arc:** Surprising stat → Deeper context → Tutorial step 1 → Tutorial step 2 → Full guide CTA

**Authority arc:** Hot take → Supporting evidence → Case study → How-to → Follow for more

**Story arc:** Origin / backstory → The struggle → The breakthrough → The lesson → The ask

## Setup Notes

- Store `active-campaign.json` in a data directory accessible to both this skill and `/social-draft`
- Trust scores from this skill and `/social-draft` use the same file — they share state
- Instagram/Facebook/Reddit/YouTube require manual posting until you build automation workflows
- Google Calendar events act as posting reminders — they don't auto-post
