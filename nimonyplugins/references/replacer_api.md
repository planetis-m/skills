# Replacer API

A complete template plugin that rewrites `sayIt(value)` into `echo value`.

```nim
# sayit.nim
template sayIt*(value: untyped): untyped {.plugin: "sayitplug".}
```

```nim
# sayitplug.nim
import plugins

var r = loadReplacer()
replaceHead r, CallS, r.info:
  drop r, Any       # template name
  r.dest.addIdent "echo"
  keep r, Expr      # template argument
saveReplacer r
```

```nim
# app.nim
import std / syncio
import sayit

sayIt "hello"
```

Operation contracts:

| Operation | Effect |
| --- | --- |
| `keep r, K` | Copy and consume one matching child |
| `drop r, K` | Consume one matching child |
| `replace r, K, x` | Consume one child and emit `x` |
| `keepTag r:` | Preserve a head; the body consumes every child |
| `loopKeepTag r:` | Preserve a head and recursively process its children |
| `replaceHead r, K, info:` | Emit a new head; the body consumes every child |

## Key points

- Template input starts with the invoked template name, so the rewrite drops
  that child before keeping the argument.
- Kind arguments assert the current child's kind.
- This template output is semantically checked again, so the raw `echo`
  identifier resolves at the call site.

## When to use

Use `Replacer` when most input children or subtrees can be kept, dropped, or
replaced without rebuilding them token by token.
