---
name: disk-space-guard
enabled: true
event: bash
pattern: "(npm install|yarn install|pnpm install|pip install|docker build)"
action: warn
---

Before installing packages or building Docker images, check available disk space.
Warn if less than 5GB available on the main partition.
