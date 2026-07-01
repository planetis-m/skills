# For-Loop Plugin

A complete for-loop plugin that repeats a typed loop body a literal number of
times.

```nim
# repeat.nim
iterator repeat*(count: int): int {.plugin: "repeatplug".}
```

```nim
# repeatplug.nim
import plugins

proc transform(root: NifCursor): NifBuilder =
  var args = firstChild(forLoopCallArgs(root))
  if not args.hasMore or args.kind != IntLit:
    return errorTree("repeat expects an integer literal", root)
  let count = int(args.intValue)
  skip args
  if args.hasMore or count < 0:
    return errorTree("repeat expects one non-negative integer", root)

  let body = forLoopBody(root)
  if body.stmtKind != StmtsS:
    return errorTree("repeat expects a statement body", body)

  result = createTree()
  result.withTree StmtsS, root.info:
    for _ in 0 ..< count:
      var statement = firstChild(body)
      while statement.hasMore:
        result.addSubtree statement
        skip statement

let input = loadPluginInput()
saveTree transform(input)
```

```nim
# app.nim
import std / assertions
import repeat

var runs = 0
for _ in repeat(3):
  inc runs

assert runs == 3
```

## Key points

- `forLoopCallArgs` returns the iterator arguments and `forLoopBody` returns
  the already typed body.
- Copy the body’s statements, rather than nesting the body’s `StmtsS` node.
- Generated output is semantically checked after it replaces the loop.

## When to use

Use a for-loop plugin when an iterator-like DSL needs to rewrite, schedule, or
expand a loop body.
