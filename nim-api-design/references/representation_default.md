# Plain Object Default

Use `object` for value semantics and `ref object` for shared identity.

```nim
type
  Rect* = object
    x*, y*, w*, h*: int

  RectRef* = ref object
    x*, y*, w*, h*: int

let a = Rect(x: 12, y: 22, w: 40, h: 80)
var copied = a
copied.x = 10
doAssert a.x == 12
doAssert copied.x == 10

var r = RectRef(x: 12, y: 22, w: 40, h: 80)
var alias = r
alias.x = 10
doAssert r.x == 10
doAssert alias.x == 10
```

## Key points

- Assigning `Rect` copies its scalar fields, so changing `copied` does not change `a`.
- Assigning `RectRef` aliases one instance; use a reference type only when shared identity or mutation is part of the contract.
