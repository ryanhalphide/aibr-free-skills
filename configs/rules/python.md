---
paths: "**/*.py"
---

- Use type hints on all function signatures.
- Prefer `async/await` for I/O-bound operations (httpx, aiohttp).
- Use `Decimal` for financial calculations, never float.
- Use `dataclasses` or `pydantic` for structured data, not raw dicts.
- Use `pathlib.Path` over `os.path`.
- For trading code: always validate order sizes against risk limits before execution.
