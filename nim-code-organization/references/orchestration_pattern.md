Choose local variables for a self-contained calculation and explicit state when
several operations share an invariant.

```nim
type
  ReportState = object
    accepted: int
    rejected: int
    messages: seq[string]

proc recordAccepted(st: var ReportState; name: string) =
  inc st.accepted
  st.messages.add "accepted " & name

proc recordRejected(st: var ReportState; name: string) =
  inc st.rejected
  st.messages.add "rejected " & name

proc buildReport(names: openArray[string]): seq[string] =
  var state: ReportState
  for name in names:
    if name.len > 0:
      state.recordAccepted(name)
    else:
      state.recordRejected("<empty>")

  result = state.messages
  result.add "accepted " & $state.accepted
  result.add "rejected " & $state.rejected

proc countNonEmpty(names: openArray[string]): int =
  for name in names:
    if name.len > 0:
      inc result
```

## Key points

- `countNonEmpty` is linear and needs no state type.
- `ReportState` is useful because multiple operations maintain related counts
  and messages.
- The object exposes shared mutation without introducing reference identity.
- Extract state and helpers because they express invariants, not merely to
  shorten the driver.
