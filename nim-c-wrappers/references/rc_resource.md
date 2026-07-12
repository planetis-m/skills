# Reference-Counted Resource Wrapper

Pattern for shared-ownership resources using a manual reference count.

```nim
type
  LIB_Asset {.importc, incompleteStruct.} = object

proc LIB_Load*(path: cstring): ptr LIB_Asset {.importc, cdecl.}
proc LIB_FreeAsset*(p: ptr LIB_Asset) {.importc, cdecl.}

type
  Asset* = object
    raw: ptr LIB_Asset
    rc: ptr int

proc `=destroy`*(a: Asset) =
  if a.raw != nil:
    if a.rc[] == 0:
      LIB_FreeAsset(a.raw)
      dealloc(a.rc)
    else:
      dec a.rc[]

proc `=wasMoved`*(a: var Asset) =
  a.raw = nil
  a.rc = nil

proc `=sink`*(dest: var Asset; src: Asset) =
  `=destroy`(dest)
  dest.raw = src.raw
  dest.rc = src.rc

proc `=copy`*(dest: var Asset; src: Asset) =
  if src.raw != nil: inc src.rc[]
  `=destroy`(dest)
  dest.raw = src.raw
  dest.rc = src.rc

proc `=dup`*(src: Asset): Asset =
  # Field-by-field assignment — do NOT use `result = src`
  result.raw = src.raw
  result.rc = src.rc
  if result.raw != nil:
    inc result.rc[]

proc loadAsset*(path: string): Asset =
  let raw = LIB_Load(path.cstring)
  if raw == nil:
    raise newException(IOError, "Failed to load asset: " & path)
  result = Asset(
    raw: raw,
    rc: cast[ptr int](alloc0(sizeof(int))))
```

## Key points

- RC counter starts at 0.
- `=copy` increments the source counter, destroys the old destination, then shares the pointer.
- `=dup` increments the counter and shares the pointer.
- `=destroy` decrements the counter. When it reaches 0, free the C resource and deallocate the counter.
- **Do not** write `result = src` in `=dup` — use field-by-field assignment to avoid triggering `=copy` implicitly.
- Use this pattern only when the C API genuinely supports shared ownership. For exclusive ownership, prefer the move-only pattern.
