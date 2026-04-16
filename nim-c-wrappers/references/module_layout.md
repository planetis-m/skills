# Module Layout

```
libname/
├── bindings/
│   └── libname_raw.nim  # Raw FFI — importc procs, C types, constants only
└── libname.nim          # Ergonomic wrapper
```

## Pattern A: Facade (default)

`import` + `export` — downstream sees both raw and ergonomic symbols.

```nim
# libname.nim
import ./bindings/libname_raw
export libname_raw

type
  Lib* = object
    handle: LibHandle

proc `=destroy`*(lib: var Lib) =
  if lib.handle != nil:
    lib_close(lib.handle)

proc `=sink`*(dest: var Lib; src: Lib) =
  `=destroy`(dest)
  dest.handle = src.handle

proc `=wasMoved`*(lib: var Lib) =
  lib.handle = nil

proc open*(path: string): Lib =
  result.handle = lib_open(path)
```

## Pattern B: Opaque

`from ... import nil` — raw symbols stay qualified behind `libname_raw.`, downstream only sees ergonomic API.

```nim
# libname.nim
from ./bindings/libname_raw import nil

type
  Lib* = object
    handle: libname_raw.LibHandle

proc `=destroy`*(lib: var Lib) =
  if lib.handle != nil:
    libname_raw.lib_close(lib.handle)

proc `=sink`*(dest: var Lib; src: Lib) =
  `=destroy`(dest)
  dest.handle = src.handle

proc `=wasMoved`*(lib: var Lib) =
  lib.handle = nil

proc open*(path: string): Lib =
  result.handle = libname_raw.lib_open(path)
```

## Rules

- Raw module: `importc` procs, C types, constants only. No Nim logic.
- Wrapper imports from raw — never the reverse.
- Default to Pattern A. Use Pattern B when raw symbols clash with ergonomic names or pollute the namespace.
- Thin wrappers where the C API is already the public API: skip the split, use a single flat module.
