# Replacer API

Use this when a plugin keeps most of the input tree and selectively rewrites,
drops, or wraps subtrees. Use direct `NifBuilder` construction instead when the
output is mostly synthetic.

## Mental Model

`Replacer` owns one input cursor and one output builder:

- `src` is the private forward-only `NifCursor`.
- `dest` is the public `NifBuilder` for output.
- Every `keep`, `drop`, and `replace` consumes exactly one current input child.
- `saveReplacer(r)` writes `r.dest`.

Template plugin input is wrapped in a `StmtsS` node. For `foo(42)`, the
Replacer starts at `(stmts 42)`, not at `42`.

## Operation Contracts

| Operation | Consumes input | Emits output | Use when |
| --- | --- | --- | --- |
| `keep r, K` | one child matching `K` | original child | preserving one child |
| `drop r, K` | one child matching `K` | nothing | removing one child |
| `replace r, K, x` | one child matching `K` | `x` | swapping one child |
| `keepTag r:` | current node and all children | same head | rebuilding a node |
| `loopKeepTag r:` | current node and all children | same head | recursively preserving a node |
| `replaceHead r, NewTag, info:` | current node and all children | new head | changing only the node head |

`K` is an assertion, not a filter. Use `Any`, `Expr`, `Type`, `Stmt`, `Def`,
`Sym`, `Dot`, `Lit`, `Nested`, or a concrete tag such as `CallX`, `CallS`,
`AsgnS`, or `ObjectT`. A mismatch is a plugin bug and exits with an assertion
failure.

`keepTag` and `replaceHead` bodies must consume every child. Forgetting a child
also exits with an assertion failure.

## Default Skeletons

Root rewrite for a template plugin that turns `sayIt(42)` into `echo 42`:

```nim
# sayitapi.nim
template sayIt*(x: untyped): untyped {.plugin: "sayitplugin".}
```

```nim
# sayitplugin.nim
import plugins

var r = loadReplacer()
replaceHead r, CallS, r.info:
  r.dest.addIdent "echo"
  while getCursor(r).hasMore:
    keep r, Expr
saveReplacer(r)
```

Recursive selective rewrite:

```nim
proc rewrite(r: var Replacer) =
  if r.isAtom:
    keep r, Any
  elif isCallTo(getCursor(r), "dropMe"):
    drop r, CallX
  elif isCallTo(getCursor(r), "replaceMe"):
    replace r, CallX, replacementTree(r.info)
  else:
    loopKeepTag r:
      rewrite r
```

Use `loopKeepTag` when preserving the current head. Use `replaceHead` when the
current head changes. Inside `replaceHead`, use `while getCursor(r).hasMore`
because `src` is private and there is no exported `hasMore(Replacer)` helper.

## Lookahead

Use `NifCursor` copies for read-only classification:

```nim
proc isCallTo(n: NifCursor; name: string): bool =
  if n.kind != ParLe or n.exprKind != CallX:
    return false
  var child = firstChild(n)
  result = child.hasMore and child.eqIdent(name)
```

Use `peek` only to inspect ahead and restore the source cursor:

```nim
proc shouldDrop(r: var Replacer): bool =
  result = false
  peek r:
    let c = getCursor(r)
    result = isCallTo(c, "dropMe")
```

Never write to `r.dest` inside `peek`. `peek` restores only the input cursor;
output already emitted to `dest` remains.

Use `getCursor` / `setCursor` for manual save and retry:

```nim
let saved = getCursor(r)
if not tryRewrite(r):
  setCursor(r, saved)
  keep r, Any
```

## Error Handling

Use Replacer operations only when the plugin knows the input shape. If the
user's input is unsupported or ambiguous, stop the transform and write an
`errorTree`:

```nim
saveTree errorTree("expected a call expression", getCursor(r))
```

Do not rely on Replacer assertions for user-facing errors. Assertions diagnose
plugin misuse such as consuming the wrong kind or failing to consume all
children.

## Key Points

- Enter or replace the `StmtsS` wrapper before consuming template arguments.
- Treat `keep`, `drop`, and `replace` as one-child operations.
- Pass the narrowest correct expected kind so misuse fails early.
- Emit synthetic structure through `r.dest`, outside `peek`.
- Prefer `loopKeepTag` for recursive pass-through transforms.
- Finish with exactly one of `saveReplacer(r)` or `saveTree(errorTree(...))`.
