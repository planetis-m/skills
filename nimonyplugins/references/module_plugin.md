# Module Plugin: Strip Debug Blocks

```nim
# app.nim
import std/syncio
{.plugin: "stripblocks".}

echo "production code"

block:
  echo "debug only"

echo "more production code"
```

```nim
# stripblocks.nim
import nimonyplugins

proc transform(n: NifCursor): NifBuilder =
  result = createTree()
  var n = n
  if n.stmtKind == StmtsS: inc n
  result.withTree StmtsS, n.info:
    while n.kind != ParRi:
      if n.kind == ParLe and n.stmtKind == BlockS:
        skip n
      else:
        result.takeTree n

var inp = loadPluginInput()
saveTree transform(inp)
```

Key points
- Declared as `{.plugin: "name".}` at the top of a module — no template needed.
- Input is the whole module wrapped in `StmtsS`. Skip the wrapper with `inc n`.
- `while n.kind != ParRi` walks all top-level children.
- `skip n` removes a subtree; `takeTree` copies it into the output unchanged.
- Must return the complete module — cannot return an empty tree.
- Same pattern works for any `stmtKind`: strip `VarS`, inject `ProcS`, reorder children.
