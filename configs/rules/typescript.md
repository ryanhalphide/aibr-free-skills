---
paths: "**/*.ts,**/*.tsx"
---

- Use strict TypeScript: no `any`, no `as` casts unless absolutely necessary.
- Prefer `async/await` over `.then()` chains.
- Use descriptive names: `getUserById` not `getUser`. Variables that are booleans: `isActive`, `hasPermission`.
- Export types from the file where they're defined. Import types with `import type`.
- Use `satisfies` for type narrowing where appropriate.
- Prefer `const` assertions for literal types.
