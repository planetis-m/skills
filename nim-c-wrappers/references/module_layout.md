# Module Layout

Raw FFI bindings in a `bindings/` subfolder, with ergonomic wrapper at the top level.

```
libname/
├── bindings/
│   └── libname_raw.nim  # Raw FFI bindings
└── libname.nim          # Ergonomic wrapper
```

```nim
# bindings/libname_raw.nim
type
  LibHandle* = ptr object

{.push importc, callconv: cdecl.}

proc lib_open*(path: cstring): LibHandle
proc lib_close*(handle: LibHandle)
proc lib_do_work*(handle: LibHandle, data: cint): cint

{.pop.}

# libname.nim
import ./bindings/libname_raw

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

proc doWork*(lib: var Lib; data: int): int =
  lib_do_work(lib.handle, data.cint)
```

## When to use

- Use this layout for every C library wrapper.
- Keep the `_raw.nim` file focused on FFI types and `importc` procs only.
- Put ownership hooks, safe types, and ergonomic helpers in the wrapper.
- The wrapper imports from `bindings/libname_raw` and never the reverse.
