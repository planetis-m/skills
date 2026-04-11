# Deep-owning container

A type that manually allocates backing storage and owns all elements. Copy produces an independent deep copy.

```nim
type
  Container = object
    data: ptr int
    len: int

proc `=destroy`*(x: Container) =
  if x.data != nil:
    dealloc(x.data)

proc `=wasMoved`*(x: var Container) =
  x.data = nil
  x.len = 0

proc `=dup`*(src: Container): Container {.nodestroy.} =
  result = Container(len: src.len, data: nil)
  if src.data != nil and src.len > 0:
    result.data = cast[ptr int](alloc(src.len * sizeof(int)))
    copyMem(result.data, src.data, src.len * sizeof(int))

proc `=copy`*(dest: var Container; src: Container) =
  if dest.data == src.data: return
  `=destroy`(dest)
  `=wasMoved`(dest)
  dest.len = src.len
  if src.data != nil and src.len > 0:
    dest.data = cast[ptr int](alloc(src.len * sizeof(int)))
    copyMem(dest.data, src.data, src.len * sizeof(int))

proc initContainer(items: openArray[int]): Container =
  result = Container(len: items.len, data: nil)
  if items.len > 0:
    result.data = cast[ptr int](alloc(items.len * sizeof(int)))
    for i in 0..<items.len:
      (cast[ptr UncheckedArray[int]](result.data))[i] = items[i]
```

Key points:
- `{.nodestroy.}` on `=dup` prevents the compiler from destroying `result` before the caller receives it
- Self-assignment guard in `=copy` is required — without it, destroy wipes the source before copying
- Nil and zero-length guards prevent `alloc(0)` crashes
