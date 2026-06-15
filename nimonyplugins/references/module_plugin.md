# Module Plugin: Full-Module Transform

```nim
# app.nim
import std/syncio
{.plugin: "modulepass".}

echo "module plugin input"
```

```nim
# modulepass.nim
import plugins

proc passModule(n: NifCursor): NifBuilder =
  result = createTree()
  var n = n
  if n.stmtKind == StmtsS:
    n = firstChild(n)
  result.withTree StmtsS, n.info:
    while n.hasMore:
      result.takeTree n

var inp = loadPluginInput()
saveTree passModule(inp)
```

Key points
- Declared as `{.plugin: "name".}` at the top of a module — no template needed.
- Input is the whole module wrapped in `StmtsS`. Skip the wrapper with `firstChild`.
- `while n.hasMore` walks all top-level children (bounded, safe).
- Must return the complete module — cannot return an empty tree.
- Use this low-level shape when constructing or reordering at the top level.
- For selective recursive rewrites that keep most of the module, use `references/replacer_api.md`.
