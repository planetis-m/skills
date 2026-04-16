# Module Layout

```
src/
├── bindings/
│   └── foo_raw.nim  # Raw FFI — importc procs, C types, constants only
└── foo.nim          # Ergonomic wrapper
```

```nim
# bindings/foo_raw.nim
when defined(windows):
  const fooDll = "foo.dll"
elif defined(macosx):
  const fooDll = "libfoo(.3|.1|).dylib"
else:
  const fooDll = "libfoo.so(.3|.1|)"

type
  Color* {.bycopy.} = object
    r*, g*, b*, a*: uint8

  Rect* {.bycopy.} = object
    x*, y*, width*, height*: float32

  Texture* {.bycopy.} = object
    id*: uint32
    width*: int32
    height*: int32

  PixelFormat* = distinct cint

const
  FormatUncompressedR8g8b8a8* = PixelFormat(1)

{.push callconv: cdecl, importc, dynlib: fooDll.}

proc libLoadTexture*(path: cstring): Texture
proc libUnloadTexture*(texture: Texture)
proc libDrawTexture*(texture: Texture; source, dest: Rect; color: Color)

{.pop.}
```

```nim
# foo.nim
import ./bindings/foo_raw
export foo_raw

proc `=destroy`*(t: Texture) =
  libUnloadTexture(t)
proc `=wasMoved`*(x: var Texture) =
  x.id = 0
proc `=dup`*(src: Texture): Texture {.error.}
proc `=copy`*(dest: var Texture; src: Texture) {.error.}

proc loadTexture*(path: string): Texture =
  result = libLoadTexture(path.cstring)
  if result.id == 0:
    raise newException(IOError, "Failed to load texture: " & path)

proc drawTexture*(texture: Texture; src, dest: Rect; tint: Color) {.inline.} =
  libDrawTexture(texture, src, dest, tint)
```

## Rules

- Raw module: `importc` procs, C types, constants only. No Nim logic.
- Wrapper imports raw with `import` + `export` — gives downstream access to both layers.
- Wrapper imports from raw — never the reverse.
- Struct types (`Color`, `Rect`, `Texture`) pass through as-is — do not wrap them in Nim types.
- Ergonomic procs use Nim types (`int`, `float`, `string`) for scalar params and returns. Convert to C types at the raw call boundary.
- Thin wrappers where the C API is already the public API: skip the split, use a single flat module.
- Avoid `from ... import nil` — it forces every type and proc through a module qualifier, adding noise with no real benefit.
