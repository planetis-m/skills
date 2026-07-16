# Move-Only Resource Wrapper

Complete pattern for wrapping a C create/destroy handle as a Nim move-only object.

```nim
type
  LIB_Handle {.importc, incompleteStruct.} = object

proc LIB_Create*(width, height: cint): ptr LIB_Handle {.importc, cdecl.}
proc LIB_Destroy*(h: ptr LIB_Handle) {.importc, cdecl.}

type
  Handle* = object
    raw: ptr LIB_Handle

proc `=destroy`*(h: Handle) =
  if h.raw != nil:
    LIB_Destroy(h.raw)

proc `=wasMoved`*(h: var Handle) =
  h.raw = nil

proc `=sink`*(dest: var Handle; src: Handle) {.error.}
proc `=copy`*(dest: var Handle; src: Handle) {.error.}
proc `=dup`*(src: Handle): Handle {.error.}

proc newHandle*(width, height: int): Handle =
  let raw = LIB_Create(cint width, cint height)
  if raw == nil:
    raise newException(ValueError, "Failed to create handle")
  Handle(raw: raw)
```

## Key points

- `{.error.}` on `=copy` and `=dup` prevents accidental double-free at compile time.
- `{.error.}` on `=sink` prevents ownership transfer after construction.
- Use `ensureMove(x)` to initialize a move-only owner from an existing variable when copying must be rejected.
- `=wasMoved` must nil out the raw pointer so `=destroy` is a no-op on moved-from objects.
- Raise immediately on nil from the C create function.
