# Enum-Like Values and Bitflags

Pattern for wrapping C enums and bitflags without using Nim `enum` or `set`.

## Enum-like values

```nim
type
  LibMode* = distinct cint

const
  LIB_ModeA* = LibMode(0)
  LIB_ModeB* = LibMode(2)
  LIB_ModeC* = LibMode(3)
  
proc `==`*(a, b: LibMode): bool {.borrow.}
```

## Bitflags with distinct type

```nim
type
  LibFlags* = distinct cuint

const
  LIB_FLAG_READ* = LibFlags(1'u32 shl 0)
  LIB_FLAG_WRITE* = LibFlags(1'u32 shl 1)
  LIB_FLAG_EXEC* = LibFlags(1'u32 shl 2)

proc `==`*(a, b: LibFlags): bool {.borrow.}

proc `+`*(a, b: LibFlags): LibFlags {.inline.} =
  LibFlags(cuint(a) or cuint(b))

proc `-`*(a, b: LibFlags): LibFlags {.inline.} =
  LibFlags(cuint(a) and not cuint(b))

proc `*`*(a, b: LibFlags): LibFlags {.inline.} =
  LibFlags(cuint(a) and cuint(b))

proc `<=`*(a, b: LibFlags): bool {.inline.} =
  (cuint(a) and not cuint(b)) == 0

proc contains*(flags: LibFlags; flag: LibFlags): bool {.inline.} =
  (cuint(flags) and cuint(flag)) != 0

proc incl*(a: var LibFlags; flag: LibFlags) {.inline.} =
  a = LibFlags(cuint(a) or cuint(flag))

proc excl*(a: var LibFlags; flag: LibFlags) {.inline.} =
  a = LibFlags(cuint(a) and not cuint(flag))
```

## Key points

- Use `distinct` int types — never Nim `enum` in raw bindings.
- `distinct` provides type safety while keeping bitwise operations explicit via helpers.
- Keep constant names close to upstream C names for easy cross-referencing.
