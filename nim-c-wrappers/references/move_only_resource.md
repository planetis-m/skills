# Move-Only Resource Wrapper

Complete pattern for wrapping a C create/destroy handle as a Nim move-only object.

```nim
type
  LibHandle {.importc: "LIB_Handle", incompleteStruct.} = object

proc libCreate*(width, height: cint): ptr LibHandle
  {.importc: "LIB_Create", cdecl.}
proc libDestroy*(h: ptr LibHandle)
  {.importc: "LIB_Destroy", cdecl.}

type
  Handle* = object
    raw: ptr LibHandle

proc `=destroy`*(h: Handle) =
  if h.raw != nil:
    libDestroy(h.raw)

proc `=wasMoved`*(h: var Handle) =
  h.raw = nil

proc `=sink`*(dest: var Handle; src: Handle) =
  `=destroy`(dest)
  dest.raw = src.raw

proc `=copy`*(dest: var Handle; src: Handle) {.error.}
proc `=dup`*(src: Handle): Handle {.error.}

proc initHandle*(width, height: int): Handle =
  result.raw = libCreate(cint width, cint height)
  if result.raw == nil:
    raise newException(ValueError, "Failed to create handle")
```

## Key points

- `{.error.}` on `=copy`/`=dup` prevents accidental double-free at compile time.
- Use `ensureMove()` to transfer ownership between variables.
- `=wasMoved` must nil out the raw pointer so `=destroy` is a no-op on moved-from objects.
- Raise immediately on nil from the C create function.
