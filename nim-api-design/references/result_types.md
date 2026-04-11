# Named Result Objects vs Status Tuples

Use named objects for semantic results. Do not expose public status tuples.

## Anti-pattern: status tuple

```nim
proc render(): tuple[ok: bool, payload: seq[byte], errorMessage: string] =
  discard
```

Problems:
- Callers have to remember to inspect `ok` on every use.
- `errorMessage` is just a string, not a typed failure path.
- The tuple shape does not document which fields are valid on success vs failure.

## Correct: named result type and exceptions for contract failures

```nim
type
  RenderSummary = object
    pageCount: Natural
    warnings: seq[string]

proc renderDocument*(path: string): RenderSummary {.raises: [ValueError].} =
  if path.len == 0:
    raise newException(ValueError, "path is empty")
  result = RenderSummary(pageCount: 1, warnings: @[])
```

## Key points

- A named result object tells the caller what the successful shape is.
- Contract violations still raise exceptions instead of flowing through a
  secondary string channel.
- The exported proc makes that stable contract explicit with
  `{.raises: [ValueError].}`.
- Keep the public result shape focused on successful semantic data.
