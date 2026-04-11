# Move-only owner

A type that exclusively owns a resource. Copying is forbidden.

```nim
type
  Buffer = object
    data: ptr int
    len: int

proc `=destroy`*(x: Buffer) =
  if x.data != nil:
    dealloc(x.data)

proc `=wasMoved`*(x: var Buffer) =
  x.data = nil

proc `=copy`*(dest: var Buffer; src: Buffer) {.error.}

proc initBuffer(items: openArray[int]): Buffer =
  result = Buffer(len: items.len, data: nil)
  if items.len > 0:
    result.data = cast[ptr int](alloc(items.len * sizeof(int)))
    for i in 0..<items.len:
      (cast[ptr UncheckedArray[int]](result.data))[i] = items[i]
```

Use this pattern for: file handles, socket handles, mmap regions, exclusive locks.
