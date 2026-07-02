---
name: nim-error-handling
description: Design clear Nim error-handling flows; when to raise exceptions vs return `Option`/`bool`, how to enforce non-raising contracts, and where to translate or record failures. Use when reviewing failure behavior, exception boundaries, recovery, or batch processing that needs per-item error reporting.
---

# Nim Error Handling

## Rules

### Choose the Failure Channel

- Raise when the caller must handle an outcome as failure, such as invalid data or failed I/O.
- Return `bool` when success or failure is the whole result.
- Return `Option[T]` when success produces a value but absence is expected.
- Use `bool` with a `var` parameter only when filling or mutating caller-owned storage is part of the API.
- Convert per-item failures into structured outcomes at the batch boundary. Keep intermediate steps exception-based.

### Place Boundaries

- Let failures propagate through intermediate steps.
- Catch only where the handler can recover, translate, or record the failure.
- At a batch boundary, record recoverable per-item failures. If recording itself fails, let that failure escape to the application boundary.

### Choose Exception Types

- Raise an existing specific type such as `ValueError`, `IOError`, or `OSError` when it fits.
- Separate `except` branches when handling differs. Group exception types when handling is identical. Put more specific types first — Nim dispatches first-match, so a parent before a child makes the child branch unreachable with no warning.
- Catch `CatchableError` only when the boundary handles every recoverable error. Do not catch bare `Exception`.
- Add a custom exception only when callers handle it differently. Derive it from the closest existing `CatchableError` subtype.
- Derive from `Defect` only for programming bugs that callers should not recover from.

### Translate and Inspect Errors

- Translate errors only at module or subsystem boundaries. Add local context and preserve the original reason.
- If the handler only needs the message text, use `getCurrentExceptionMsg()`.
- If the handler needs exception fields, use `except X as e`.

### Cleanup and Contracts

- Use `try/finally` for cleanup.
- Use `{.raises: [].}` when a proc must not raise. Leave raising procs unannotated.

## Workflow

1. **Choose the failure channel** for each failure point: raise, return `bool`, return `Option[T]`, or structured per-item outcome.
2. **Pick the exception type.** Prefer existing stdlib types; add a custom type only when callers handle it differently.
3. **Place catch boundaries** only where the handler can recover, translate, or record the failure.
4. **Enforce contracts.** Add `{.raises: [].}` to procs that must not raise.

## Common Mistakes

| Mistake | Why it is wrong |
|---------|-----------------|
| Parent `except` before child | Nim dispatches first-match, so the child branch is unreachable. Put specific types first. |
| Using `except Exception` to catch all errors | It catches `Defect` too, masking programming bugs as recoverable. Catch `CatchableError` instead. |

## References

- Read `references/batch_preview_boundary.md` when a batch must record per-item failures but abort if its reporting path fails.
