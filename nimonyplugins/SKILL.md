---
name: nimonyplugins
description: Write Nimony plugins against `src/nimony/lib/nimonyplugins.nim` using the codebase's actual `Cursor`/`TokenBuf` idioms, with correct `Tree`/`Node` mental models, traversal patterns, and construction workflows.
---

# Nimony Plugins

Use this skill when writing or reviewing plugins built on `src/nimony/lib/nimonyplugins.nim`.

This skill is grounded in the Nimony frontend code under `src/nimony/*.nim`. It does not describe hypothetical plugin styles. It describes the patterns that the compiler itself uses with raw `TokenBuf` and `Cursor`, then maps those patterns to the plugin-facing `Tree` and `Node` API.

## Mental Model

Treat the plugin API like this:

- `Tree` is the plugin-facing analogue of `TokenBuf`.
- `Node` is the plugin-facing analogue of `Cursor`.

That is only a mental model, not an exact type alias.

What the code actually shows:

- Raw compiler code uses plain `TokenBuf` as mutable storage and `Cursor` as borrowed read positions.
- Plugin code uses `Tree` and `Node`, which add ownership and validation semantics on top.

Important API differences:

- `Tree` is copy-on-write.
  Evidence: `Tree` stores shared payload plus a refcount-like `counter`, and every mutator goes through `prepareMutation`.
- `Node` is an owned read handle, not just a naked position.
  Evidence: `snapshot(tree)` starts `beginRead`; `Node` destruction calls `endRead`; `Node` copies use `shareRead`.
- `snapshot(tree)` requires a non-empty tree.
  Evidence: it asserts `not tree.isEmpty`.
- Constructed plugin trees are validated.
  Evidence: `validateConstructedTree` and `validateConstructedNode` are called by the construction helpers.

The safe rule is:

- Think of `Tree` as an owned mutable builder.
- Think of `Node` as an owned read cursor into a stable snapshot.

## Core API Roles

Use these operations as the main vocabulary:

- `createTree()`: start a new mutable output tree.
- `snapshot(tree)`: get a read handle for a finished or partially finished tree.
- `withTree(kind, info): ...`: canonical structured emission.
- `addParLe` / `addParRi`: manual structured emission when `withTree` is not enough.
- `takeTree(var node)`: copy current token or subtree and advance the reader.
- `addSubtree(node)`: copy current token or subtree without advancing the reader.
- `inc(node)`: single-token advance.
- `skip(node)`: skip current token, or whole subtree when at `ParLe`.
- `errorTree(...)`: emit an `ErrT` tree with source attachment when available.
- `saveTree(...)`: write final NIF output.

## Mapping From Compiler Idioms

The compiler repeatedly uses these raw patterns:

- Borrowed destructive traversal with `var Cursor`.
- Copying whole subtrees with `takeTree` and non-consuming copies with `addSubtree`.
- Building a temporary `TokenBuf`, then rereading it with `beginRead` or `cursorAt`.
- Holding a backing buffer alive for as long as any derived cursor is needed.

The plugin API maps to them like this:

- Raw `Cursor` traversal maps to moving a `var Node`.
- Raw `TokenBuf` construction maps to mutating a `Tree`.
- Raw reread patterns map to building a `Tree` and then calling `snapshot`.
- Raw manual `beginRead`/`endRead` balancing is replaced by `Node` ownership.

## Canonical Read Patterns

### 1. Treat traversal as destructive by default

The compiler nearly always walks a `var Cursor` forward and does not try to keep it immutable. Plugin code should do the same with `var Node`.

Use:

- `kind`, `stmtKind`, `exprKind`, `typeKind`, `pragmaKind`, `otherKind` to inspect the current node.
- `skip(node)` when you want to consume the whole current subtree.
- `inc(node)` only when you intentionally want single-token motion.

Recommended shape:

```nim
var n = input
if n.exprKind == CallX:
  inc n         # step into children
  # inspect children here
else:
  skip n        # consume whole subtree you do not handle
```

Why this is idiomatic:

- Compiler transforms such as `deferstmts.nim` are written as single-pass cursor consumers.
- The plugin API makes the same pattern explicit with `inc` and `skip`.

### 2. Clone readers for lookahead

Raw compiler code often copies a cursor before probing shape, because a cursor is just a position. Do the same with `Node`: copy it when you want lookahead without committing to movement on the original.

Recommended shape:

```nim
var probe = n
inc probe
if probe.kind == Symbol:
  # commit later if wanted
```

Why this is idiomatic:

- Many compiler helpers probe by copying `Cursor` values, then advancing the copy.
- `Node` copies are supported explicitly and share the underlying read state safely.

### 3. Distinguish token stepping from subtree stepping

Do not use `inc(node)` when your intent is “move past this whole node”.

Use:

- `inc(node)` for atom-by-atom stepping.
- `skip(node)` for structural stepping.

This matters because the underlying representation is flat tokens, not heap-linked AST nodes.

## Canonical Write Patterns

### 1. Prefer structured emission

The compiler overwhelmingly emits trees in this order:

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

The compiler regularly preserves already-built structure instead of reconstructing it token-by-token.

In plugins:

- Use `takeTree(var node)` when consuming input into output.
- Use `addSubtree(node)` when preserving input but leaving the reader in place.

This is the most important operational distinction in the plugin API.

Rule of thumb:

- If the source reader should move, use `takeTree`.
- If the source reader should stay put, use `addSubtree`.

### 3. Build while consuming

Compiler transforms commonly read from one tree and emit to another in lockstep. Mirror that style in plugins.

Recommended workflow:

```nim
var outp = createTree()
var n = input

outp.withTree(StmtsS, n.info):
  while n.kind != ParRi:
    if shouldRewrite(n):
      emitRewrite(outp, n)  # consumes from n
    else:
      outp.takeTree(n)
```

This is the closest plugin equivalent to the compiler's `TokenBuf` + `Cursor` transformation style.

### 4. Snapshot after construction, not during mutation-heavy assembly

The compiler often builds a temporary buffer completely, then rereads it. Follow the same staged approach in plugins:

1. Build a `Tree`.
2. Call `snapshot(tree)` when you need a reader.
3. Traverse with `Node`.

Do not treat a mutable `Tree` itself as the thing you inspect. Treat it as backing storage.

## Ownership And Lifecycle

These rules are directly supported by the code:

- A raw `Cursor` is only valid while its backing `TokenBuf` is alive.
- A plugin `Node` keeps the backing tree alive for you.
- Copying a `Tree` does not mean shared mutation; later writes detach.
- Copying a `Node` creates another read handle to the same underlying tree snapshot.

Practical consequences:

- Do not assume a copied `Tree` sees later mutations performed through another copy.
- Do not snapshot an empty tree.
- Do not manually reason as if `Node` were a plain integer offset; it has read-lifetime behavior attached.

## Construction Contracts

The plugin API validates constructed nodes. That means shape matters.

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
    result.takeTree(n)   # callee
    while n.kind != ParRi:
      result.takeTree(n) # args
```

Why this matches the codebase:

- The compiler's transforms commonly consume a reader while appending to a destination buffer.

### Pattern: inspect without consuming

Use when you need a predicate or branch decision but still need the original node later.

```nim
proc isSimpleIdent(n: Node): bool =
  var probe = n
  result = probe.kind == Ident
```

Why this matches the codebase:

- Cursor copies are routinely used for lookahead in the frontend.

### Pattern: synthesize temporary structure, then reread it

Use when downstream logic is easier to express against normal tree shape than against ad hoc state.

```nim
var tmp = createTree()
tmp.withTree(TupleT, NoLineInfo):
  tmp.addSubtree(a)
  tmp.addSubtree(b)
let tmpNode = snapshot(tmp)
```

Why this matches the codebase:

- `typenav`, `expreval`, and `sem.nim` repeatedly build temporary buffers and then reopen them as cursors.

### Pattern: preserve original source on errors

Use `errorTree(msg, at)` or `errorTree(msg, at, orig)` rather than constructing a bare `ErrT` by hand.

Why this matches the codebase:

- Both the compiler and plugin API preserve original source subtrees inside error nodes.

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

The compiler codebase frequently preserves existing subtrees. Plugins should do the same because it is simpler and less error-prone.

## Recommended Workflow

1. Load input with `loadPluginInput`.
2. Traverse with one primary `var Node`.
3. Copy the node for lookahead when needed.
4. Build output in a fresh `Tree`.
5. Preserve existing structure with `takeTree` or `addSubtree` unless a rewrite is necessary.
6. Use `errorTree` for invalid cases instead of ad hoc malformed output.
7. Save the final tree with `saveTree`.

## Minimal Working Style

Use this style as the default plugin shape:

```nim
import src/nimony/lib/nimonyplugins

proc transform(input: Node): Tree =
  result = createTree()
  var n = input
  while n.kind != ParRi:
    if n.exprKind == CallX:
      result.withTree(CallX, n.info):
        inc n
        result.takeTree(n)
        while n.kind != ParRi:
          result.takeTree(n)
    else:
      result.takeTree(n)
```

This is not a promise that every plugin should look exactly like this. It is the safest default because it matches the compiler's own proven `Cursor`/`TokenBuf` transformation style.
