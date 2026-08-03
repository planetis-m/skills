Use an explicit value object when an incremental API preserves cursor state
and lifecycle invariants between calls.

```nim
type
  WordScanner = object
    input: string
    pos: int
    opened: bool

proc open(s: var WordScanner; input: string) =
  s = WordScanner(input: input, opened: true)

proc skipSpaces(s: var WordScanner) =
  while s.pos < s.input.len and s.input[s.pos] == ' ':
    inc s.pos

proc next(s: var WordScanner): string =
  assert s.opened
  s.skipSpaces()
  let start = s.pos
  while s.pos < s.input.len and s.input[s.pos] != ' ':
    inc s.pos
  result = s.input[start..<s.pos]

proc close(s: var WordScanner) =
  s = WordScanner()
```

## Key points

- The value object owns the input, cursor, and lifecycle flag.
- `open`, `next`, and `close` make state transitions explicit.
- The private helper operates on the same `var WordScanner` without hidden
  capture.
- This shape fits incremental consumers; a one-shot split operation should
  remain a simple proc.
