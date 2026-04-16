# Type Plugin: Field-Aware Passthrough

```nim
# traceable.nim
type
  Traceable* {.plugin: "traceplugin".} = object
    id*: int
    name*: string
```

```nim
# traceplugin.nim
import nimonyplugins
import std/os

proc transform(n: Node): Tree =
  result = createTree()
  var n = n
  if n.stmtKind == StmtsS: inc n
  result.withTree StmtsS, n.info:
    while n.kind != ParRi:
      result.takeTree n

let moduleAst = loadPluginInput()          # paramStr(1): the module
let typeAst = loadPluginInput(paramStr(3)) # paramStr(3): the type def
discard renderNode(typeAst)                # inspect fields here

saveTree transform(moduleAst)
```

```nim
# app.nim
import std/syncio
import traceable

var item = Traceable(id: 1, name: "test")
item.id = 2
echo item.id
echo item.name
```

Key points
- Declared on the type: `type T {.plugin: "name".} = object ...`.
- Fires for every module that imports and uses the type, not just the defining module.
- `loadPluginInput()` reads the module AST; `loadPluginInput(paramStr(3))` reads the type definition.
- The type definition AST contains field names and types — parse it to know what to intercept.
- Must return the complete module; use `takeTree` for unchanged statements, `skip` + construction for rewrites.
- Real extensions: inject `echo` on field writes, generate `==`/`$` from fields, add serialization hooks.
