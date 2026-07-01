Use an explicit value object when an incremental API preserves cursor state
and lifecycle invariants between calls.

```nim
type
  WordScanner = object
    input: string
    pos: int
    opened: bool

proc open(scanner: var WordScanner; input: string) =
  scanner = WordScanner(input: input, opened: true)

proc skipSpaces(scanner: var WordScanner) =
  while scanner.pos < scanner.input.len and scanner.input[scanner.pos] == ' ':
    inc scanner.pos

proc next(scanner: var WordScanner): string =
  doAssert scanner.opened
  scanner.skipSpaces()
  let start = scanner.pos
  while scanner.pos < scanner.input.len and scanner.input[scanner.pos] != ' ':
    inc scanner.pos
  result = scanner.input[start..<scanner.pos]

proc close(scanner: var WordScanner) =
  scanner = WordScanner()

var scanner: WordScanner
scanner.open("alpha beta")
doAssert scanner.next() == "alpha"
doAssert scanner.next() == "beta"
doAssert scanner.next() == ""
scanner.close()
doAssert not scanner.opened
```

## Key points

- The value object owns the input, cursor, and lifecycle flag.
- `open`, `next`, and `close` make state transitions explicit.
- The private helper operates on the same `var WordScanner` without hidden
  capture.
- This shape fits incremental consumers; a one-shot split operation should
  remain a simple proc.
