---
name: nim-error-handling
description: Design clear Nim error-handling flows; when to raise exceptions vs return `Option`/`bool`, how to enforce non-raising contracts, and where to translate or record failures. Use when reviewing failure behavior, exception boundaries, recovery, or batch processing that needs per-item error reporting.
---

# Nim Error Handling

## Rules

### Choose the Failure Channel

- Return `bool` when success or failure is the whole result.
- Return `Option[T]` when success returns a value but absence is expected.
- Use `bool` with a `var` parameter only when filling or mutating caller-owned storage is part of the API.
- Convert per-item failures into structured outcomes at the batch boundary. Keep intermediate steps exception-based.

### Validate at Boundaries

- Add a failure path only when the condition prevents the operation from meeting its contract.
- Use range types only as parameters.
- Do not use range conversions; they raise `Defect` and silently accept invalid values under `-d:danger`.

### Place Boundaries

- Let failures propagate through intermediate steps.
- Catch only where the handler can recover, translate, or record the failure.
- At a batch boundary, record recoverable per-item failures.

### Choose Exception Types

- For a contract failure caused by caller input or the environment, raise the closest existing `CatchableError`.
- Separate `except` branches when handling differs. Group exception types when handling is identical.
- Put child exception types before their parents in `except` branches.
- Catch `CatchableError` only when the boundary handles every recoverable error. Do not catch bare `Exception`.
- Add a custom exception only when callers handle it differently. Derive it from the closest existing `CatchableError` subtype.
- Use `Defect` only when a contract failure proves an internal invariant is broken.

### Translate and Inspect Errors

- Translate errors only at module or subsystem boundaries. Add local context and preserve the original reason.
- If the handler only needs the message text, use `getCurrentExceptionMsg()`.
- If the handler needs exception fields, use `except X as e`.

### Cleanup and Contracts

- Use `try/finally` for cleanup.
- Use `{.raises: [].}` when a proc must not raise. Leave raising procs unannotated.

## Workflow

1. **Define the operation's postcondition and trust boundaries.**
2. **Classify only conditions that prevent that postcondition.**
3. **Place catch boundaries** only where the handler can recover, translate, or record the failure.
4. **Enforce contracts.** Add `{.raises: [].}` to procs that must not raise.

## Common Mistakes

| Mistake | Why it is wrong |
|---------|-----------------|
| Parent `except` before child | Nim dispatches first-match, so the child branch is unreachable. Put specific types first. |
| Using `except Exception` to catch all errors | It catches `Defect` too, masking programming bugs as recoverable. Catch `CatchableError` instead. |

## References

- Read `references/batch_preview_boundary.md` when a batch must record per-item failures but abort if its reporting path fails.
