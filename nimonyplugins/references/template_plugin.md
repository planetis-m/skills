# Template Plugin

A complete template plugin that computes a string from literal arguments at
compile time.

```nim
# repeated.nim
template repeated*(text: string; count: int): string {.plugin: "repeatedplug".}
```

```nim
# repeatedplug.nim
import plugins

proc transform(root: NifCursor): NifBuilder =
  var arg = callArgs(root)
  if arg.kind != StrLit:
    return errorTree("repeated expects a string literal", root)
  let text = arg.stringValue
  skip arg

  if arg.kind != IntLit:
    return errorTree("repeated expects an integer literal count", root)
  let count = int(arg.intValue)
  skip arg
  if count < 0:
    return errorTree("repeated expects a non-negative count", root)

  var value = ""
  for _ in 0 ..< count:
    value.add text
  result = createTree()
  result.addStrLit value

let input = loadPluginInput()
saveTree transform(input)
```

```nim
# app.nim
import std / assertions
import repeated

assert repeated("na", 4) == "nananana"
```

## Key points

- `callArgs` starts at the template’s first argument.
- Invalid call-site input becomes an `errorTree` with source location.
- A template plugin can return one expression; its output is semantically
  checked at the call site.

## When to use

Use a template plugin for macro-like call-site generation or a small
compile-time DSL.
