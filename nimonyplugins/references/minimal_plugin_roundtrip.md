# Minimal End-to-End Plugin

Use this shape for a small compile-time rewrite.

Public module:

```nim
template shout*(spec: string): untyped {.plugin: "shoutplugin".}
```

Plugin module:

```nim
import std/strutils
import nimonyplugins

proc extractArg(n: Node): Node =
  result = n
  if result.stmtKind == StmtsS:
    inc result
  if result.kind == ParLe and result.exprKind == SufX:
    inc result

let root = loadPluginInput()
let arg = extractArg(root)

if arg.kind == StringLit:
  var resultTree = createTree()
  resultTree.addStrLit(arg.stringValue.toUpperAscii)
  saveTree(resultTree)
else:
  saveTree errorTree("shout expects a string literal", arg)
```

Caller:

```nim
import std / syncio
import shoutdsl

echo shout"hello"
```

Key points
- The public surface is a `template` with `{.plugin: "name".}`.
- The plugin reads the input with `loadPluginInput()`.
- The plugin emits one replacement tree and ends with `saveTree(...)`.
- On invalid input, the plugin emits `errorTree(...)` instead of crashing.
