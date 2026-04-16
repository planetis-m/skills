# Template Plugin: Compile-Time Lookup Table

```nim
# app.nim
import std/syncio

template buildPopcountLut(): untyped {.plugin: "poplut".}

let PopLut: array[256, int] = buildPopcountLut()

proc popcnt(x: int): int =
  var u = cast[uint64](x)
  var s = 0
  for k in 0..7:
    s += PopLut[int((u shr (k * 8)) and 0xFF'u64)]
  s

echo popcnt(13)   # 3
echo popcnt(255)  # 8
echo popcnt(-1)   # 64
```

```nim
# poplut.nim
import nimonyplugins

proc popc8(i: int): int =
  var v = i
  var c = 0
  while v != 0:
    v = v and (v - 1)
    inc c
  c

proc tr(n: Node): Tree =
  result = createTree()
  result.withTree BracketX, n.info:
    for i in 0..<256:
      result.addIntLit popc8(i)

var inp = loadPluginInput()
saveTree tr(inp)
```

Key points
- Template plugins replace a bodiless `template ... {.plugin: "name".}` at each call site.
- The plugin runs real computation and emits NIF that the compiler splices in.
- `withTree BracketX` builds an array literal; `addIntLit` emits each element.
- The caller types the result (`array[256, int]`) to constrain what the plugin must produce.
- Same pattern works for CRC tables, Base64 alphabets, sine approximations — any compile-time table.
