---
name: nim-error-handling
description: Design clear Nim error-handling flows; when to raise exceptions vs return `Option`/`bool`, how to define `raises` contracts, and where to translate or record failures. Use when reviewing failure behavior, parse errors, exception boundaries, or batch processing that needs per-item error reporting.
---

# Nim Error Handling

Use this skill to decide where code should raise, catch, translate, or return structured failure data.

## Rules

### Choose the Failure Channel

- Raise exceptions for invalid input, semantic/validation failure, and operational/runtime failure (I/O, OS, network).
- Return `bool` for probe-style queries where failure means “not found / condition not met” and no value payload is needed.
- Return `Option[T]` when the absent value is a value type with no natural sentinel and the caller benefits from composable operations like `map` or `flatMap`.
- For scanning/parsing helpers, return consumed length as `int` (`0` = no match) and write the parsed value via a `var` out-parameter.
- Use structured result objects only at the orchestrator/batch boundary, where exceptions are converted into per-item outputs.
- Do not pass ad-hoc `(ok, kind, message)` step-result objects through straight-line internal flows.

### Place Boundaries

- Internal step procs should raise (do not catch in the same layer).
- Catch only to recover, translate at a boundary, record failure, or clean up.
- Keep the success path straight-line between boundaries.
- Do not wrap each raising call in its own local `try/except`.

### Choose Exception Types

- Catch `CatchableError` as the recoverable catch-all. Do not catch bare `Exception`.
- Use specific existing exception types such as `ValueError`, `IOError`, and `OSError` when callers should distinguish them.
- Add a custom exception type only when callers need a narrower semantic type for distinct handling.
- Custom exception types must derive from `CatchableError` (recoverable) or `Defect` (programming bugs).
- Inherit from a more specific existing base like `ValueError` or `IOError` when the semantic fit is clear.
- Deriving directly from `CatchableError` or `Defect` is fine when no intermediate base matches.

### Make Contracts Explicit

- Add explicit `raises` contracts on exported procs only when the exception surface is stable and narrow.
- Do not annotate every internal helper by default.
- Use `.raises: []` for a proc that must not raise.
- Use `.raises: [X]` when one specific exception type is part of the contract.
- Treat `raises` as a compiler-checked contract, not documentation prose.

### Translate and Inspect Errors

- Translate low-level errors only at module/subsystem boundaries.
- Add local context and preserve the underlying reason in the new message (include the original exception message).
- If the handler only needs the message text, use `getCurrentExceptionMsg()`.
- If the handler needs the exception object or fields, use `except X as e` or `getCurrentException()`.

### Cleanup

- Use `try/finally` for cleanup.

## Workflow

1. Decide whether failure is expected.
   If it is an expected miss, return `bool`, `Option`, or a parse-length value. Do not throw.
2. Mark the boundaries.
   Step procs raise. Parse helpers may catch once. Module boundaries may translate. Orchestrators may record per-item failure.
3. Pick the exception type.
   Start with an existing type. Add a subtype only if callers need distinct handling.
4. Write the contract.
   Add `raises` on exported procs when the exception surface is narrow and stable. Keep it accurate.
5. Verify the shape.
   Compile the code. Run the repo tests. If you wrote `raises`, ensure the compiler accepts the contract.

## Minimal Pattern

```nim
import std/[options]

proc findConfig*(paths: seq[string]): Option[string] =
  for p in paths:
    if fileExists(p):
      return some(p)
  none(string)

proc loadConfig*(path: string): Config =
  if path.len == 0:
    raise newException(ValueError, "config path is empty")
  try:
    result = parseConfig(readFile(path))
  except IOError:
    raise newException(IOError, "cannot read config: " & getCurrentExceptionMsg())
```

## Common Mistakes

| Mistake | Why it is wrong |
|---------|-----------------|
| Catching in every layer | Hides the real boundary and makes failure flow harder to follow |
| Throwing for an expected miss | Turns normal control flow into exception flow |
| Passing `ok/kind/message` objects between internal steps | Reimplements exception propagation with more boilerplate |
| Catching bare `Exception` | Also catches `Defect`, which is not recoverable application flow |
| Adding a custom exception type with no distinct handling | Adds type noise without changing the contract |
| Using `try/except` for cleanup | Cleanup belongs in `finally` |

## References

- `references/batch_preview_boundary.md` — Batch boundary that records per-item failures

## Changelog

- 2026-04-09: Initial skill.
- 2026-04-11: Added `raises` contracts, exception base-class rules, expected-miss return channels.
- 2026-04-14: Refined failure channel guidance.
- 2026-04-17: Removed retry advice.
