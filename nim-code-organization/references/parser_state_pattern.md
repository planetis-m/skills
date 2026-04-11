# Parser-Style State Object

Use one explicit state object and top-level procs when a module has a step-by-step orchestration flow.

```nim
type
  WriteState = object
    nextToWrite: int
    ready: seq[bool]
    writtenIds: seq[string]

proc markReady(state: var WriteState; idx: int) =
  state.ready[idx] = true

proc flushReady(state: var WriteState; ids: openArray[string]) =
  while state.nextToWrite < ids.len and state.ready[state.nextToWrite]:
    state.writtenIds.add ids[state.nextToWrite]
    inc state.nextToWrite

proc run(ids: openArray[string], completionOrder: openArray[int]): seq[string] =
  var state = WriteState(
    nextToWrite: 0,
    ready: newSeq[bool](ids.len),
    writtenIds: @[]
  )

  for idx in completionOrder:
    markReady(state, idx)
    flushReady(state, ids)

  result = state.writtenIds
```

## Key points

- Shared mutable flow lives in one named object.
- Helper procs mutate `var WriteState` explicitly.
- The driver proc stays short because the state flow is named and visible.
- This matches the shape used by stdlib parser-style modules better than nested helper captures.
