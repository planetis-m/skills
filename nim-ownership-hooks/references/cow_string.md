# Copy-on-write string (CoW)

A common pattern: multiple strings share a payload. Mutation detaches by allocating a fresh copy.

```nim
type
  StrPayload = object
    cap, counter: int
    data: UncheckedArray[char]

  String = object
    len: int
    p: ptr StrPayload  # nil when len == 0

template contentSize(cap): int = cap + 1 + sizeof(object(cap: 0, counter: 0))

template frees(s) =
  when compileOption("threads"):
    deallocShared(s.p)
  else:
    dealloc(s.p)

proc `=destroy`*(x: String) =
  if x.p != nil:
    if x.p.counter == 0:
      frees(x)
    else:
      dec x.p.counter

proc `=wasMoved`*(x: var String) =
  x.p = nil

template dups(a, b) =
  if b.p != nil:
    inc b.p.counter
  a.p = b.p
  a.len = b.len

proc `=dup`*(b: String): String =
  dups(result, b)

proc `=copy`*(a: var String; b: String) =
  `=destroy`(a)
  dups(a, b)

proc initString*(s: var String; data: string) =
  `=destroy`(s)
  `=wasMoved`(s)
  s.len = data.len
  if data.len > 0:
    s.p = cast[ptr StrPayload](alloc(contentSize(data.len)))
    s.p.cap = data.len
    s.p.counter = 0
    copyMem(addr s.p.data[0], unsafeAddr data[0], data.len + 1)
  else:
    s.p = nil

proc getStr*(s: String): string =
  if s.p == nil: return ""
  result = newString(s.len)
  copyMem(addr result[0], addr s.p.data[0], s.len)

proc mutateAt*(s: var String; i: int; c: char) =
  if s.p.counter > 0:
    let oldP = s.p
    s.p = cast[ptr StrPayload](alloc(contentSize(oldP.cap)))
    s.p.cap = oldP.cap
    s.p.counter = 0
    copyMem(addr s.p.data[0], addr oldP.data[0], s.len + 1)
    dec oldP.counter
  s.p.data[i] = c
```

This follows the preferred inverted counter convention from the local `cowstrings` project:
- `counter == 0` → exclusively owned, free on destroy
- `counter > 0` → shared, decrement on destroy
- `=copy` has no self-assign guard — destroy decrements, `dups` increments, net zero
- `=dup` has no `{.nodestroy.}` — refcount balances

Source: simplified from `/home/ageralis/Projects/cowstrings/cowstrings.nim`.
