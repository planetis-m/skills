---
name: nimonyplugins
description: Write correct Nimony plugins against the actual installed `nimonyplugins.nim` API, with clear `Tree`/`Node` usage and safe traversal and construction patterns.
---

# Nimony Plugins

Use this skill when writing or reviewing plugins built on `nimonyplugins`.

## First Step

Open the `nimonyplugins.nim` used by the exact `nimony` executable you will run.
Resolve that executable first with `readlink -f "$(command -v nimony)"`.
If that executable is `.../bin/nimony`, open `../src/nimony/lib/nimonyplugins.nim` from there.
Otherwise open `src/nimony/lib/nimonyplugins.nim` under the executable's directory.

## Mental Model

Treat the plugin API like this:

- `Tree` is the mutable builder you write into.
- `Node` is the read handle you traverse.

Important API differences:

- `Tree` is copy-on-write.
- `Node` is an owned read handle.
- `snapshot(tree)` requires a non-empty tree.
- Constructed plugin trees are validated.

Safe rule:

- Think of `Tree` as owned mutable output.
- Think of `Node` as a stable read cursor into a snapshot.

## Core API Roles

Use these operations as the main vocabulary:

- Tree creation:
  `createTree()` starts empty output.
  `createTree(kind; children...)` and `createTree(kind, info; children...)` build a validated node in one call.
  `isEmpty(tree)` is the guard before `snapshot(tree)`.
  `snapshot(tree)` gives you a readable `Node` at the start of the tree.
  `withTree(kind, info): ...` is the normal way to emit a balanced node.
- Node inspection:
  `kind` and `info` tell you the raw token kind and source location.
  `stmtKind`, `exprKind`, `typeKind`, `otherKind`, `pragmaKind` tell you which plugin-level node category you are looking at.
  `tagId`, `tagText`, `tag` are for raw tag inspection when you need exact NIF shape.
  `symId`, `symText`, `identText`, `stringValue`, `charLit`, `intValue`, `uintValue`, `floatValue` read the payload of the current token.
  `eqIdent(name)` is the quick exact-name check for identifiers and symbols.
- Traversal:
  `inc(node)` advances one token.
  `skip(node)` skips the whole current subtree, or the current token if it is atomic.
- Tree construction:
  `addParLe(tagId|string, info)` and `addParRi()` are the manual open/close primitives.
  `takeTree(t, var node)` copies the current subtree and advances the reader.
  `addSubtree(t, node)` copies the current subtree without advancing the reader.
  `add(t, childTree)` appends another whole `Tree`.
  `addDotToken()` emits `.`.
  `addStrLit`, `addIntLit`, `addUIntLit`, `addIdent`, `addCharLit`, `addFloatLit` emit literal or identifier atoms.
  `addSymUse(symId|string, info)` emits a symbol-use token.
  `addEmptyNode`, `addEmptyNode2`, `addEmptyNode3`, `addEmptyNode4` emit one to four `.` placeholders when a node shape requires empty children.
- IO and rendering:
  `loadPluginInput()` reads `paramStr(1)` by default and returns the input root as `Node`.
  `saveTree(tree)` writes to `paramStr(2)` by default.
  `saveTree(tree, filename)` writes explicit output.
  `renderTree(tree)` renders raw NIF text for debugging.
  `renderNode(node)` renders the current subtree for debugging.
- Line info:
  `isValid(info)` checks whether source info exists.
  `filePath(info)` returns the source path.
  `lineCol(info)` returns decoded line and column.
- Error construction:
  `errorTree(msg)` builds a synthetic error node.
  `errorTree(msg, at)` uses `at` for source location and origin.
  `errorTree(msg, at, orig)` uses `at` for location and `orig` as embedded source.

## Canonical Read Patterns

### 1. Treat traversal as destructive by default

Treat traversal as moving a `var Node` forward. Do not design around immutable walkers unless you actually need them.

Use:

- `kind`, `stmtKind`, `exprKind`, `typeKind`, `pragmaKind`, `otherKind` to inspect the current node.
- `skip(node)` when you want to consume the whole current subtree.
- `inc(node)` only when you intentionally want single-token motion.

Recommended shape:

```nim
var n = input
if n.exprKind == CallX:
  inc n
  # inspect children here
else:
  skip n
```

### 2. Clone readers for lookahead

Copy `Node` when you want lookahead without committing to movement on the original.

Recommended shape:

```nim
var probe = n
inc probe
if probe.kind == Symbol:
  # commit later if wanted
```

### 3. Distinguish token stepping from subtree stepping

Do not use `inc(node)` when your intent is “move past this whole node”.

Use:

- `inc(node)` for atom-by-atom stepping.
- `skip(node)` for structural stepping.

This matters because the representation is token-based, not heap-linked nodes.

## Canonical Write Patterns

### 1. Prefer structured emission

Emit trees in this order:

1. Open tag
2. Emit children
3. Close tag

In plugins, prefer:

```nim
result.withTree(CallX, src.info):
  result.addSubtree(fn)
  result.addSubtree(arg)
```

Use manual `addParLe` / `addParRi` only when conditional structure makes `withTree` awkward.

### 2. Reuse existing subtrees whenever possible

Preserve already-correct subtrees instead of reconstructing them token by token.

Use:

- `takeTree(var node)` when consuming input into output.
- `addSubtree(node)` when preserving input but leaving the reader in place.

Rule of thumb:

- If the source reader should move, use `takeTree`.
- If the source reader should stay put, use `addSubtree`.

### 3. Build while consuming

Read from one tree and emit to another in lockstep when transforming structure.

Recommended workflow:

```nim
var outp = createTree()
var n = input

outp.withTree(StmtsS, n.info):
  while n.kind != ParRi:
    if shouldRewrite(n):
      emitRewrite(outp, n)
    else:
      outp.takeTree(n)
```

### 4. Snapshot after construction, not during mutation-heavy assembly

Build first, then reread:

1. Build a `Tree`.
2. Call `snapshot(tree)` when you need a reader.
3. Traverse with `Node`.

Do not treat a mutable `Tree` itself as the thing you inspect. Treat it as backing storage.

## Ownership And Lifecycle

These rules matter:

- `Node` keeps the backing tree alive for you.
- Copying a `Tree` does not mean shared mutation; later writes detach.
- Copying a `Node` creates another read handle to the same underlying tree snapshot.

Practical consequences:

- Do not assume a copied `Tree` sees later mutations performed through another copy.
- Do not snapshot an empty tree.
- Do not treat `Node` like a plain integer offset.

## Construction Contracts

The plugin API validates constructed nodes. Shape matters.

Follow these rules:

- Emit balanced trees.
- Match the expected child categories for the tag you are constructing.
- Prefer subtree reuse over handwritten low-level token assembly when possible.
- Use `NoLineInfo` only for genuinely synthetic structure.
- Preserve source `info` from existing nodes when output is derived from them.

## Canonical Patterns

### Pattern: consume-and-reemit

Use when rewriting one subtree into another and preserving most children.

```nim
proc rewriteCall(n: var Node): Tree =
  result = createTree()
let info = n.info
  result.withTree(CallX, info):
    inc n
    result.takeTree(n)
    while n.kind != ParRi:
      result.takeTree(n)
```

### Pattern: inspect without consuming

Use when you need a predicate or branch decision but still need the original node later.

```nim
proc isSimpleIdent(n: Node): bool =
  var probe = n
  result = probe.kind == Ident
```

### Pattern: synthesize temporary structure, then reread it

Use when downstream logic is easier to express against normal tree shape than against ad hoc state.

```nim
var tmp = createTree()
tmp.withTree(TupleT, NoLineInfo):
  tmp.addSubtree(a)
  tmp.addSubtree(b)
let tmpNode = snapshot(tmp)
```

### Pattern: preserve original source on errors

Use `errorTree(msg, at)` or `errorTree(msg, at, orig)` rather than constructing a bare `ErrT` by hand.

## Do

- Do think in terms of linear token streams plus structural delimiters.
- Do use `takeTree` and `addSubtree` intentionally; they are not interchangeable.
- Do copy a `Node` when you need lookahead.
- Do build output in a fresh `Tree` and snapshot it only when you need reading.
- Do preserve source line info when transforming an existing subtree.
- Do prefer `withTree` for balanced structured output.
- Do reuse source subtrees instead of rebuilding them when their shape is already correct.

## Don't

- Do not assume `Tree` mutation is shared across copies.
- Do not assume `Node` is just a raw cursor with no lifetime semantics.
- Do not call `snapshot` on an empty tree.
- Do not use `inc(node)` as a substitute for `skip(node)` when the current node may have children.
- Do not reconstruct large existing subtrees token-by-token unless you are actually changing them.
- Do not hand-emit malformed node shapes and expect downstream code to accept them.

## Common Pitfalls

### Confusing `takeTree` with `addSubtree`

This is the most likely plugin bug.

- `takeTree(var node)` advances.
- `addSubtree(node)` does not.

If later logic assumes the node moved and it did not, or vice versa, the rest of the traversal will be wrong.

### Forgetting that the representation is token-based

If you `inc` into a subtree and then forget to close or skip it structurally, your traversal state will drift.

Prefer subtree-level operations unless single-token control is necessary.

### Treating copied trees as shared mutable state

`Tree` detaches on mutation. A copied `Tree` is not a live shared builder.

### Rebuilding structure that the source tree already has

Preserve existing subtrees when they are already correct. It is simpler and less error-prone.

## Recommended Workflow

1. Locate and read the actual installed `nimonyplugins.nim`.
2. Load input with `loadPluginInput`.
3. Traverse with one primary `var Node`.
4. Copy the node for lookahead when needed.
5. Build output in a fresh `Tree`.
6. Preserve existing structure with `takeTree` or `addSubtree` unless a rewrite is necessary.
7. Use `errorTree` for invalid cases instead of ad hoc malformed output.
8. Save the final tree with `saveTree`.

## Minimal Working Style

Call site:

```nim
template generateEcho(s: string) {.plugin: "deps/mplugin1".}

generateEcho("Hello, world!")
```

Plugin file:

```nim
import nimonyplugins

proc tr(n: Node): Tree =
  result = createTree()
  let info = n.info
  var n = n
  if n.stmtKind == StmtsS:
    inc n
  result.withTree(StmtsS, info):
    result.withTree(CallS, info):
      result.addIdent "echo"
      result.takeTree(n)

var inp = loadPluginInput()
saveTree tr(inp)
```
