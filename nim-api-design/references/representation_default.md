# Plain Object Default

Use a plain `object` by default. Switch to `ref object` only when the API needs shared identity.

```nim
type
  Rect = object
    x, y, w, h: int

  RectRef = ref object
    x, y, w, h: int

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

- A plain `object` copy does not create a second access path to the same fields.
- A `ref object` assignment aliases the same instance.
- For plain data models, start with `object`.
- Use `ref object` only when the caller must observe shared identity or shared mutation.
