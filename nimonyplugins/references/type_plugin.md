# Type Plugin

A complete type plugin that rejects global variables whose type is marked
`StackOnly`, while allowing local values.

```nim
# stackonly.nim
type
  StackOnly* {.plugin: "stackonlyplug".} = object
    value*: int
```

```nim
# stackonlyplug.nim
import plugins

proc triggeringTypes(root: NifCursor): seq[SymId] =
  result = @[]
  var item = firstChild(root)
  while item.hasMore:
    if item.kind == Symbol:
      result.add item.symId
    skip item

proc forbiddenGlobal(root: NifCursor; types: seq[SymId]): NifCursor =
  result = NifCursor()
  if root.kind == TagLit and root.stmtKind == GvarS:
    var field = firstChild(root)
    skip field # name
    skip field # export marker
    skip field # pragmas
    if field.kind == Symbol and field.symId in types:
      return root
  if root.kind == TagLit:
    var child = firstChild(root)
    while child.hasMore:
      result = forbiddenGlobal(child, types)
      if result.hasMore:
        return
      skip child

proc copyModule(root: NifCursor): NifBuilder =
  var root = root
  result = createTree()
  result.takeTree root

proc moduleError(message: string; at: NifCursor;
                 info: LineInfo): NifBuilder =
  result = createTree()
  result.withTree StmtsS, info:
    result.addTree errorTree(message, at)

let moduleRoot = loadPluginInput()
let types = triggeringTypes(loadTypeDefinitions())
let bad = forbiddenGlobal(moduleRoot, types)
if bad.hasMore:
  saveTree moduleError("StackOnly values must be local", bad, moduleRoot.info)
else:
  saveTree copyModule(moduleRoot)
```

```nim
# app.nim
import std / [assertions, syncio]
import stackonly

proc main() =
  var item = StackOnly(value: 42)
  assert item.value == 42

main()
echo "TYPE: PASS"
```

This use is rejected at the declaration:

```nim
# bad.nim
import stackonly

var item = StackOnly(value: 42)
```

## Key points

- `loadTypeDefinitions` provides the triggering type symbols;
  `loadPluginInput` provides the typed module that uses them.
- Type-plugin errors must still be returned as a complete `StmtsS` module.
- Valid output preserves the complete typed module because type-plugin output
  is not semantically checked again.

## When to use

Use a type plugin for validation or rewriting driven by selected types.
