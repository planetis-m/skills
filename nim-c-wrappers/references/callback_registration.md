# Callback Registration

Pattern for registering Nim callbacks with cdecl plus rooted state keyed by `userdata`.

```nim
import std/tables

type
  LibOnEvent* = proc(userdata: pointer; code: cint) {.cdecl.}
  EventState = ref object
    total*: int

proc libSetOnEvent*(cb: LibOnEvent; userdata: pointer)
  {.importc: "LIB_SetOnEvent", cdecl.}

var eventStates: Table[pointer, EventState]

proc eventBridge(userdata: pointer; code: cint) {.cdecl.} =
  eventStates[userdata].total += int(code)

proc setOnEvent*(state: EventState) =
  let userdata = cast[pointer](eventStates.len + 1)
  eventStates[userdata] = state
  libSetOnEvent(eventBridge, userdata)
```

## Key points

- Callbacks must be `{.cdecl.}` — C expects a plain function pointer, not a Nim closure.
- Store Nim state in a global table keyed by `userdata`, not in closures.
- Ensure any GC-managed data referenced by callbacks is globally rooted.
