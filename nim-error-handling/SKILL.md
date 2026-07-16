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

### Add Only Real Failure Paths

- Read what the current operation promises and how each called API reports failure.
- If a successful call guarantees valid output, do not add another nil, size, or range check.
- If a condition breaks no documented promise, remove the check and document the valid behavior.
- Report failure when the result cannot safely satisfy its API or the operation cannot meet its documented promise.
- If an operation requires a stronger guarantee than the API it calls, validate that guarantee in that operation.

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
- Do not use `Defect` for recoverable failures; it represents a programming bug and is not caught by `CatchableError`.
- Do not use range conversions for recoverable validation; invalid values raise `RangeDefect`.

### Translate and Inspect Errors

- Translate errors only at module or subsystem boundaries. Add local context and preserve the original reason.
- If the handler only needs the message text, use `getCurrentExceptionMsg()`.
- If the handler needs exception fields, use `except X as e`.

### Cleanup and Contracts

- Use `try/finally` for cleanup.
- Use `{.raises: [].}` when a proc must not raise. Leave raising procs unannotated.

## Workflow

1. **Read the contracts.** Note what this operation promises, how called APIs report failure, and what they guarantee on success.
2. **Decide whether failure is needed.** Name the documented promise that the condition would break. If there is none, remove the check.
3. **Place the decision.** Document valid behavior as success, or report failure in the first operation whose promise is broken.
4. **Place catch boundaries.** Catch only where the handler can recover, translate, or record the failure.
5. **Enforce non-raising contracts.** Add `{.raises: [].}` only to procs that must not raise.

## Common Mistakes

| Mistake | Why it is wrong |
|---------|-----------------|
| Parent `except` before child | First-match dispatch makes the child handler unreachable. |
| Catching bare `Exception` | Also catches `Defect` and can hide programming bugs. |
| Rechecking guaranteed output | Adds dead branches and can contradict the lower-level API. |
| Rejecting allowed behavior | Silently narrows the operation's contract. |

## References

- `references/batch_preview_boundary.md` — Per-item batch failures with reporting failures allowed
  to escape.
