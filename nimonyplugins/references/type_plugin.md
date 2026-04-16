# Type Plugin: Field-Aware Passthrough

A type plugin fires for every module that uses the annotated type. It receives two inputs:
the module AST (`paramStr(1)`) and the type definition (`paramStr(3)`). This example
passes the module through unchanged while reading the type definition — the foundation
for observer injection, auto-serialization, and field-change notifications.

## Type definition (`traceable.nim`)

```nim
type
  Traceable* {.plugin: "traceplugin".} = object
    id*: int
    name*: string
```

## Plugin (`traceplugin.nim`)

```nim
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

## Caller (`app.nim`)

```nim
import std/syncio
import traceable

var item = Traceable(id: 1, name: "test")
item.id = 2
echo item.id
echo item.name
```

What this teaches:
- Declared on the type: `type T {.plugin: "name".} = object ...`
- Fires for every module that imports and uses `Traceable`, not just the defining module
- `loadPluginInput()` reads the module AST; `loadPluginInput(paramStr(3))` reads the type definition
- The type definition contains field names and types — parse it to know what to intercept
- Must return the complete module; use `takeTree` for unchanged statements, `skip` + construction for rewrites
- Real extensions: inject `echo` on field writes, generate `==`/`$` from fields, add serialization hooks
