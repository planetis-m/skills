# Shared / refcounted handle

Use one convention consistently inside the type.

## Preferred convention in this repo: inverted counter (counter=0 → unique, >0 → shared)

```nim
proc `=destroy`*(x: String) =
  if x.p != nil:
    if x.p.counter == 0:
      dealloc(x.p)     # exclusively owned, free directly
    else:
      dec x.p.counter   # shared, just decrement

proc `=wasMoved`*(x: var String) =
  x.p = nil

proc `=dup`*(b: String): String =
  # No {.nodestroy.} — refcount balances the implicit destroy
  if b.p != nil: inc b.p.counter
  result.p = b.p
  result.len = b.len

proc `=copy`*(a: var String; b: String) =
  # No self-assign guard needed — destroy+share balances via counter
  `=destroy`(a)
  if b.p != nil: inc b.p.counter
  a.p = b.p
  a.len = b.len
```

This is the default shared-ownership pattern for this repo's verified skill because it gives one consistent shape for `=destroy`, `=dup`, and `=copy`.

## Compatibility note: standard counter (counter=1 → exclusive, >1 → shared)

Use this only when matching an existing codebase that already counts the unique owner as `1`.

```nim
type
  Payload = object
    counter: int
    value: int

  Handle = object
    p: ptr Payload

proc `=destroy`*(x: Handle) =
  if x.p != nil:
    dec x.p.counter
    if x.p.counter == 0:
      dealloc(x.p)

proc `=wasMoved`*(x: var Handle) =
  x.p = nil

proc `=dup`*(b: Handle): Handle {.nodestroy.} =
  result.p = b.p
  if b.p != nil: inc b.p.counter

proc `=copy`*(a: var Handle; b: Handle) =
  if a.p == b.p: return
  `=destroy`(a)
  `=wasMoved`(a)
  a.p = b.p
  if b.p != nil: inc b.p.counter
```
