# Custom `=sink`

Only write a custom `=sink` when the compiler-synthesized version (destroy + copyMem) is insufficient. This happens when:
- The type has child objects with their own hooks that `copyMem` would bypass
- You need to update external references or bookkeeping

```nim
proc `=sink`*(dest: var T; src: T) =
  `=destroy`(dest)
  `=wasMoved`(dest)  # needed when not all fields are overwritten below
  dest.field = src.field
```

No self-assignment check — the compiler eliminates `x = x` before reaching your `=sink`.
