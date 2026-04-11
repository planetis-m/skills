Explicit state object vs nested closure pattern for orchestration code.

## Preferred: explicit state object

```nim
type
  WriteState = object
    nextToWrite: int

proc flushReady(state: var WriteState; total: int) =
  if state.nextToWrite < total:
    inc state.nextToWrite
```

## Avoid (design smell, not a bug): nested closure

```nim
proc run() =
  let total = 10
  var nextToWrite = 0
  proc flushReady() =
    if nextToWrite < total:
      inc nextToWrite
```

### Key points

- Both patterns compile and run correctly under ORC.
- The explicit state pattern makes data flow visible in the proc signature.
- Use nested closures only when the capture is short and obvious.
- For multi-step flows, the explicit state object scales better.
