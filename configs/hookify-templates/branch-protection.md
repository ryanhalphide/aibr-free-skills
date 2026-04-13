---
name: branch-protection
enabled: true
event: bash
pattern: "git push.*(main|master)"
action: warn
---

Block direct pushes to main/master branches unless explicitly confirmed by user.
Force-pushes to main/master should always be blocked with a warning.
Suggest creating a PR instead.
