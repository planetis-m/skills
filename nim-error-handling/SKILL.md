---
name: nim-error-handling
description: Design clear Nim error-handling flows, including when to raise exceptions, when to return `Option` or `bool`, how to define `raises` contracts, and where to translate, retry, or record failures. Use when reviewing failure behavior, parse errors, exception boundaries, or batch processing that needs per-item error reporting.
---

# Nim Error Handling

Use this skill when deciding where code should raise, catch, translate, retry, or return structured failure data.

## Rules

### Choose The Failure Channel

- Use exceptions for invalid data, semantic failure, and operational failure.
- Use `Option[T]`, `bool` plus `var`, or a parse-length return for expected absence or probe-style failure.
- Use structured result objects only at the orchestrator boundary, where exceptions become per-item output.
- Do not pass `ok/kind/message` step objects through straight-line internal flows.

### Place Boundaries

- Internal step procs should raise.
- Catch only to recover, translate, record failure, or clean up.
- Keep the success path straight-line between real boundaries.
- Do not wrap every raising call in its own local `try/except`.

### Choose Exception Types

- Use `CatchableError` as the recoverable catch-all. Do not catch bare `Exception`.
- Use specific existing exception types such as `ValueError`, `IOError`, and `OSError` when callers should distinguish them.
- Add a custom exception type only when callers need a narrower semantic name.
- If you add a custom exception type, derive it from the closest existing base such as `ValueError` or `IOError`.

### Make Contracts Explicit

- Write explicit `raises` contracts on exported procs when the exception surface is stable.
- Do not annotate every internal helper by default.
- Use `.raises: []` for a proc that must not raise.
- Use `.raises: [X]` when one specific exception type is part of the contract.
- Treat `raises` as a compiler-checked contract, not as documentation text.

### Translate And Inspect Errors

- Translate low-level errors only at real module or subsystem boundaries.
- Add local context and keep the underlying reason in the new message.
- If the handler only needs the message text, use `getCurrentExceptionMsg()`.
- If the handler needs fields from the exception object, use `except X as e` or `getCurrentException()`.

### Cleanup And Retry

- Use `try/finally` for cleanup.
- Separate retry decision from final-failure classification.
- After retries are exhausted, raise once or record one final failure outcome.

## Workflow

1. Decide whether failure is expected.
   If it is an expected miss, use `Option`, `bool`, or another non-exception channel.
2. Mark the real boundaries.
   Step procs raise. Parse helpers may catch once. Module boundaries may translate. Orchestrators may record per-item failure.
3. Pick the exception type.
   Start with an existing type. Add a subtype only if callers need it.
4. Write the contract.
   Add `raises` on exported procs when it improves the public contract. Keep it accurate.
5. Verify the shape.
   Compile the code. Run the repo tests. If you wrote `raises`, make sure the compiler accepts the contract.

## Minimal Pattern

```nim
import std/[parseutils]

proc fakeAuditWrite(path, line: string) =
  if path.len == 0:
    raise newException(OSError, "audit path is empty")

proc parseRetryLimit*(s: string; value: var Positive): bool {.raises: [].} =
  try:
    var parsed: int
    if parseInt(s, parsed) > 0 and parsed > 0:
      value = Positive(parsed)
      result = true
  except ValueError:
    result = false

proc writeAuditLine(path, line: string) =
  try:
    fakeAuditWrite(path, line)
  except OSError:
    raise newException(IOError, "audit write failed for " & path & ": " &
      getCurrentExceptionMsg())
```

## Common Mistakes

| Mistake | Why it is wrong |
|---------|-----------------|
| Catching in every layer | Hides the real boundary and makes failure flow harder to follow |
| Throwing for an expected miss | Turns normal control flow into exception flow |
| Passing `ok/kind/message` objects between internal steps | Reimplements exception propagation with more boilerplate |
| Catching bare `Exception` | Also catches `Defect`, which is not recoverable application flow |
| Adding a custom exception type with no distinct handling | Adds type noise without changing the contract |
| Omitting `raises` on an exported proc with a stable exception surface | Leaves part of the public error contract implicit |
| Using `try/except` for cleanup | Cleanup belongs in `finally` |
| Retrying without a separate classifier | Mixes retry policy with terminal failure handling |

## References

- `references/batch_preview_boundary.md` — Batch boundary that records per-item failures
- `references/retry_classification.md` — Retry predicate and final-failure classification

## Changelog

- 2026-04-11: Refined the skill around Zen of Nim exception tracking and stdlib patterns. Added exported-proc `raises` guidance, expected-miss return channels, and custom exception base-class rules.
- 2026-04-09: Simplified the rule set and set one project default for exception capture style.
