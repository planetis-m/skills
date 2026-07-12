Three template patterns where a `proc` cannot substitute: control-flow
abstraction with scoped cleanup, caller-named scoped access, and lazy
evaluation that is skipped entirely in release builds.

```nim
import std/[locks, tables, syncio]

# Pattern 1: Control-flow abstraction with scoped cleanup.
# A proc cannot accept an untyped body block, so try/finally cleanup must
# be duplicated at every call site without a template.
template withLock*(lock: var Lock; body: untyped) =
  acquire(lock)
  try:
    body
  finally:
    release(lock)

# Pattern 2: Caller-named scoped access.
# The caller chooses the name that the injected value will have inside
# the body. A proc parameter would not let the caller name the binding.
template withValue*[A, B](t: var Table[A, B]; key: A;
    value, body: untyped) =
  mixin hasKey, `[]`
  if t.hasKey(key):
    var value {.inject.} = addr(t[key])
    body

# Pattern 3: Lazy evaluation.
# The argument expression is not evaluated unless the condition is true.
# A proc would evaluate the argument before the call.
template debugLog*(msg: untyped) =
  when defined(debug):
    stderr.writeLine(msg)

var lock: Lock
var counter = 0

proc incrementLocked() =
  withLock(lock):
    inc counter

proc process(data: openArray[int]) =
  debugLog("processing " & $data.len & " items")
  for item in data:
    inc counter, item

var users = {1: "alice", 2: "bob"}.toTable
users.withValue(1, u):
  u[] = "ALICE"
doAssert users[1] == "ALICE"

incrementLocked()
doAssert counter == 1

process([10, 20, 30])
doAssert counter == 61
```

## Key points

- `withLock` wraps a caller body in `try/finally`, guaranteeing cleanup. A
  `proc` parameter would close over the body at runtime; a template inlines
  it directly.
- `withValue` injects a caller-chosen name bound to a scoped mutable view.
  The name `value` is selected by the caller at the call site, not by the
  template author.
- `debugLog` skips the string expression entirely when `debug` is not
  defined. A `proc` would evaluate `"processing " & $data.len & " items"`
  on every call regardless of the condition.
