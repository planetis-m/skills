# Reference-Counted Resource Wrapper

Pattern for shared-ownership resources using a manual reference count.

```nim
type
  LibAsset {.importc: "LIB_Asset", incompleteStruct.} = object

proc libLoad*(path: cstring): ptr LibAsset
  {.importc: "LIB_Load", cdecl.}
proc libFreeAsset*(p: ptr LibAsset)
  {.importc: "LIB_FreeAsset", cdecl.}

type
  Asset* = object
    raw: ptr LibAsset
    rc: ptr int

proc `=destroy`*(a: Asset) =
  if a.raw != nil:
    if a.rc[] == 0:
      libFreeAsset(a.raw)
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
  let raw = libLoad(path.cstring)
  if raw.isNil:
    raise newException(IOError, "Failed to load asset: " & path)
  result = Asset(
    raw: raw,
    rc: cast[ptr int](alloc0(sizeof(int)))
  )
```

## Key points

- RC starts at 0. `=copy` and `=dup` increment before sharing. `=destroy` decrements and frees at zero.
- **Do not** write `result = src` in `=dup` — use field-by-field assignment to avoid triggering `=copy` implicitly.
- Use this pattern only when the C API genuinely supports shared ownership. For exclusive ownership, prefer the move-only pattern.
- `dealloc(a.rc)` only happens when the last reference is destroyed (rc reaches 0).
