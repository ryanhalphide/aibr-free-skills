---
name: typescript-lint
enabled: true
event: edit
pattern: "\\.(ts|tsx)$"
action: warn
---

TypeScript file edited. If the project has eslint configured (eslint.config.mjs or .eslintrc*), run `npx eslint --no-error-on-unmatched-pattern` on the changed file to catch no-floating-promises, consistent-type-imports, and other strict rules before committing.
