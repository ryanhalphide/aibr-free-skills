# Trust Gate — Scaling AI Autonomy Progressively

## The Problem

AI agents that require human approval for every action are too slow to be useful in production. Full autonomy without guardrails is reckless. Most teams pick one extreme and accept the tradeoff: either a slow, constantly-asking assistant or a fully autonomous one they don't fully trust.

Neither is right. What you need is a system that scales autonomy based on demonstrated reliability — where trust is earned, not assumed.

## The Pattern

Maintain a JSON trust score matrix. Each action type (social media draft, social media publish, email send, deployment, file deletion) has a score that accumulates through successful, approved actions. A PreToolUse hook reads the score before any outbound action, compares it to the threshold for that action type, and either allows the action silently or blocks it for manual approval.

```json
{
  "social_draft": { "score": 85, "threshold": 50, "actions": 34, "blocked": 2 },
  "social_publish": { "score": 20, "threshold": 70, "actions": 4, "blocked": 1 },
  "email_send": { "score": 0, "threshold": 100, "actions": 0, "blocked": 0 },
  "deploy_staging": { "score": 60, "threshold": 60, "actions": 12, "blocked": 0 },
  "deploy_production": { "score": 30, "threshold": 90, "actions": 3, "blocked": 1 },
  "file_delete": { "score": 0, "threshold": 95, "actions": 0, "blocked": 0 }
}
```

## Score Accumulation

- **+5** for each action the user approves or doesn't block
- **-20** for each action the user explicitly rejects
- **Reset to 0** if the user says "stop doing that" or manually overrides

The decay is asymmetric by design. Trust is slow to build, fast to lose. This mirrors how real trust works.

## Default Thresholds

| Action | Threshold | Rationale |
|--------|-----------|-----------|
| Social media draft | 50 | Low stakes — drafts only, not published |
| Social media publish/schedule | 70 | Moderate stakes — public, but reversible |
| Email draft | 50 | Low stakes — drafts only |
| Email send | 100 | Always require explicit approval — never autonomous |
| Deploy to staging | 60 | Moderate — affects dev environment |
| Deploy to production | 90 | High stakes — requires near-perfect track record |
| File delete | 95 | Destructive — almost always require approval |
| Outbound API calls | 60 | Varies by action consequence |

## Why This Beats Explicit Approval Every Time

Manual approval gates ("Claude, can you post this?") require constant attention. They're necessary at the start but become friction after dozens of successful actions.

The trust gate automates the approval decision based on history. For actions with a proven track record (85/50 threshold: draft has earned it), Claude proceeds silently. For actions that haven't accumulated trust (20/70: publishing hasn't earned it), the block triggers and the user decides. You're not approving actions — you're managing a trust ledger.

After a few weeks of use:
- Drafting content: fully autonomous (high trust, low threshold)
- Scheduling posts: autonomous with history (trust earned through use)
- Sending emails: always blocked (threshold intentionally set to 100)
- Deploys to production: still gated until the track record justifies it

## Hook Output Format

When blocking:
```json
{"decision": "block", "reason": "social_publish trust score (20) below threshold (70). 50 more trust points needed. Approve this action to accumulate trust."}
```

When allowing (silent — no output needed):
The hook exits 0 with no output. The tool call proceeds.

## Tuning for Your Use Case

Adjust thresholds in your trust score file (`~/.claude/social-trust.json` or equivalent) based on:
- **Reversibility**: Irreversible actions (email sends, file deletes, prod deploys) get high thresholds
- **Visibility**: Public-facing actions (social posts) get moderate thresholds
- **Cost of error**: Financial transactions get 100 — always require explicit approval

Start conservative. Lower thresholds as you build confidence in a specific action type.

## Implementation

See: [`hooks/pre-tool/trust-gate.sh`](../hooks/pre-tool/trust-gate.sh)
