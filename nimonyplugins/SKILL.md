---
name: nimonyplugins
description: Build and debug Nimony compile-time plugins for code generation and DSL rewrites. Use when replacing Nim macros with Nimony plugins, writing or reviewing plugin-backed templates or module/type/import plugins, fixing generated plugin output, or diagnosing NIF traversal and source-level plugin errors.
---

# Nimony Plugins

Use this skill when writing or reviewing compile-time rewrites for Nimony.
Plugins are the Nimony replacement for macros. For new compile-time DSL rewrites, use a plugin-backed template such as `template foo*(spec: string): untyped {.plugin: "fooplugin".}`. Do not write Nim macros.
Nimony plugin code targets the `plugins` module, not Nim macro APIs.

## Rules

### Setup

- Resolve the nimony executable: `readlink -f "$(command -v nimony)"`.
- If the resolved path ends with `/bin/nimony`, open `../src/nimony/lib/plugins.nim` from there.
- Otherwise open `src/nimony/lib/plugins.nim` under the executable's directory.
- Plugin modules are compiled with Nimony itself. The compiler invokes a separate `nimony c` invocation per plugin and caches the result.
- The plugin path in `{.plugin: "path"}` is relative to the directory of the source file that contains the pragma, not the call site.

### Plugin Kinds

There are four kinds of plugins. All share the same `plugins` API.

- **Template plugin**: `template foo(...) {.plugin: "path".}` — invoked at each call site. The input is wrapped in a `StmtsS` node containing the arguments. Use `firstChild(n)` to skip past it.
- **Module plugin**: `{.plugin: "path".}` as a top-level statement — receives the entire module after semantic analysis. Must output the complete transformed module.
- **Type plugin**: `type T {.plugin: "path".} = ...` — invoked for every module that uses `T`. Receives two inputs: `paramStr(1)` for the module AST and `paramStr(3)` for the type definition.
- **Import plugin**: `import (path/foo) {.plugin: "std/v2".}` — imports `path/foo` processed through the `std/v2` plugin.

### End-To-End Shape

- Expose the rewrite through a public template such as `template foo*(spec: string): untyped {.plugin: "fooplugin".}`.
- Keep the plugin logic in a separate plugin module.
- Start with `import plugins`. Use the `Replacer` API for selective tree transforms or the low-level `NifCursor`/`NifBuilder` API for direct construction.
- For the low-level API: `let root = loadPluginInput()`. For type plugins, also load `loadPluginInput(paramStr(3))` for the triggering type definitions.
- Read the relevant input node, build output, then finish with `saveTree(resultTree)`, `saveReplacer(r)`, or `saveTree(errorTree("invalid plugin input"))`.
- Keep runtime helpers in the public module. Keep NIF traversal and code generation in the plugin module.
- Template plugins can be hidden inside imported modules so callers do not see the `.plugin` pragma.

### Mental Model

- `NifBuilder` is the mutable COW builder. Copying a `NifBuilder` shares the payload; the next mutation detaches it.
- `NifCursor` wraps a `Cursor`, which is a reference-counted shared pointer into token data. Copying a `NifCursor` increments the refcount. `NifCursor`s keep data alive even after the source `NifBuilder` is destroyed.
- `snapshot` takes `var NifBuilder` (borrows, does not consume). It calls `beginRead` under the hood, which shares buffer ownership. The tree stays writable; mutation detaches the buffer via COW.
- `snapshot` requires a non-empty tree. Guard with `isEmpty(tree)` first.
- Treat `NifBuilder` as owned mutable output. Treat `NifCursor` as a stable read handle that independently owns its data.

### Replacer API

- `loadReplacer()` loads input into `Replacer`; `saveReplacer(r)` writes `r.dest`.
- `keep r, Kind` copies one child and advances.
- `drop r, Kind` skips one child.
- `replace r, Kind, replacement` skips one child and emits a `NifCursor` or `NifBuilder`.
- `keepTag r:` copies the current node tag, processes children, closes the output node, and advances past the input close.
- `loopKeepTag r:` keeps the current node tag and iterates all children.
- `replaceHead r, NewTag, info:` enters the current input node while emitting a different output tag.
- `peek r:` runs read-ahead logic and restores the cursor afterward; do not emit inside `peek`.
- `getCursor(r)` and `setCursor(r, c)` save and restore source cursor position.
- `r.dest` is the output builder for synthetic children emitted alongside Replacer operations.
- Kind annotations are mandatory: use `Any`, `Expr`, `Type`, `Stmt`, `Def`, `Sym`, `Dot`, `Lit`, `Nested`, or a concrete tag such as `CallX`, `CallS`, `AsgnS`, or `ObjectT`.

### Low-Level Construction

- `createTree()` creates empty output.
- `createTree(kind; children...)` and `createTree(kind, info; children...)` build a validated node in one call. `kind` must be a `NimonyType`, `NimonyExpr`, `NimonyStmt`, `NimonyOther`, or `NimonyPragma` enum value — passing the enum catches typos at compile time.
- `withTree(kind, info): body` is the normal way to emit a balanced node.
- Use manual `addParLe`/`addParRi` only when conditional structure makes `withTree` awkward.
- `createTree(kind, children...)` produces validated trees. If the structure is wrong, the result is replaced with an `ErrT` node. Trees built via `withTree` or `addParLe`/`addParRi` are not validated.
- Use `NoLineInfo` only for genuinely synthetic output. Preserve source `info` when output is derived from input nodes.

### BindSym — Hygienic Symbol References

Use `bindSym` to emit symbol references that resolve at plugin definition scope rather than at the user's call site.

- At plugin sem time, `echo` resolves against the plugin module's imports and folds to the fully-qualified symbol name.
- Single match emits one `Symbol` atom; multiple matches emit a `(cchoice ...)` subtree.
- Use `brOpen` for Nim-style mixin semantics, `brForceOpen` to always wrap in `(ochoice ...)` even with one match.
- `bindSym` is a `{.magic.}` proc — `name` must be a string literal.

### Traversal

- `skip(node)` skips the whole current subtree.
- `firstChild(n)` returns a bounded cursor at the first child of a `ParLe` node — safe for iteration with `while c.hasMore`.
- `hasMore(n)` returns true while there are more children before the closing `)`.
- `into n: body` enters the current node, runs `body` to process children, advances past `)`.
- `loopInto n: body` enters the node, iterates all children, leaves.
- `balancedTokens n: body` deep-scans all `ParLe` nodes in a subtree (read-only).
- `takeTree(t, var node)` advances the reader — use it for single-token stepping when you need payload access, or for subtree consumption.
- Copy a `NifCursor` for lookahead without committing movement on the original.
- Use `kind`, `stmtKind`, `exprKind`, `typeKind`, `otherKind`, and `pragmaKind` to inspect the current node.
- Use `symId`, `symText`, `identText`, `stringValue`, `charLit`, `intValue`, `uintValue`, and `floatValue` to read payload.

### Subtree Reuse

- `takeTree(t, var node)` copies the current subtree and advances the reader.
- `addSubtree(t, node)` copies the current subtree without advancing the reader.
- `add(t, childTree)` appends a whole generated tree.
- `copyInto(t, var node): body` copies the opening tag, runs `body` to process children, closes the node, and advances past the matching `)`.
- Reuse existing subtrees when they are already correct. Do not rebuild them token by token without a reason.

### Errors And IO

- Use `errorTree(msg)` for synthetic plugin errors.
- Use `errorTree(msg, info)`, `errorTree(msg, at)`, or `errorTree(msg, at, orig)` when location matters.
- `renderTree(tree)` renders raw NIF for inspection (omits line info).
- `renderNode(node)` renders the current subtree for inspection (omits line info).
- `loadPluginInput()` reads the default plugin input from `paramStr(1)` and returns a `NifCursor`.
- `saveTree(tree)` writes the default plugin output to `paramStr(2)`, preserving line info.
- `loadReplacer()` reads input and returns a `Replacer` ready for transformation.
- `saveReplacer(r)` writes the Replacer's output to `paramStr(2)`.

### Type System

- `LineInfo` is packed source location metadata. `NoLineInfo` is the zero value.
- `SourcePos` has `line` and `col` fields (1-based, or 0 when invalid).
- `SymId` is an opaque symbol handle. Use with `addSymUse`/`addSymDef`.
- `TagId` is a raw NIF tag identifier.
- `isValid(info)`, `filePath(info)`, `lineCol(info)` decode source locations.

## Workflow

1. Resolve the real API file.
   Open the `plugins.nim` used by the exact `nimony` you will run.
2. Decide the public entrypoint.
   Export a template such as `template foo*(spec: string): untyped {.plugin: "fooplugin".}` from the user-facing module.
3. Read the plugin input.
   Use `loadPluginInput()` or `loadReplacer()`.
4. Parse string DSL input before emitting NIF.
   Convert the DSL string into ordinary Nim objects, then emit from that parsed representation.
5. Build output.
   Use `Replacer` for selective transforms. Use `NifBuilder` directly with `withTree`, subtree reuse, and helper procs when constructing output from scratch. Emit hygienic references with `bindSym` instead of raw `addSymUse` strings.
6. Finish explicitly.
   End with `saveTree(resultTree)`, `saveReplacer(r)`, or `saveTree(errorTree("invalid plugin input"))`.

## Common Mistakes

| Mistake | Why it's wrong |
|---------|----------------|
| Writing a Nim macro for a new Nimony DSL | Plugins are the compile-time rewrite mechanism in Nimony |
| Mixing the public template and the plugin rewrite logic in one module | It tangles runtime API and NIF generation logic |
| Treating `NifBuilder` as a read cursor | `NifBuilder` is output storage; `NifCursor` is the read handle |
| Using `inc` on a `NifCursor` | `inc` does not exist for `NifCursor`. Use `skip` for subtrees, `takeTree` for single atoms, or `firstChild` and `hasMore` for iteration |
| Confusing `takeTree` with `addSubtree` | One advances the reader and the other does not |
| Assuming a `NifCursor` is invalidated when its source `NifBuilder` is mutated or destroyed | The Cursor refcount keeps the data alive; `NifBuilder` mutation detaches the buffer via COW |
| Snapshotting an empty tree | `snapshot(tree)` asserts on empty input |
| Rebuilding correct input subtrees atom by atom | It is slower, noisier, and easier to get wrong than subtree reuse |
| Crashing on invalid plugin input | Emit `errorTree("invalid plugin input")` so the compiler reports a source-level plugin error |
| Assuming `withTree` output is validated | Only `createTree(kind, children)` validates; `withTree` and `addParLe`/`addParRi` do not |
| Using `addSymUse("echo", ...)` for symbols that exist in the user's scope | `bindSym` resolves the reference at plugin definition scope |

## References

- `references/template_plugin.md` — Template plugin: compile-time 256-element popcount lookup table
- `references/module_plugin.md` — Module plugin entrypoint and full-module output contract
- `references/type_plugin.md` — Type plugin: field-aware passthrough with paramStr(3)
- `references/replacer_api.md` — Replacer API patterns and an end-to-end privacy audit transform

## Changelog

- 2026-04-09: Initial skill.
- 2026-04-11: Added plugin-backed templates, loadPluginInput/saveTree flow.
- 2026-04-15: Added plugin kinds, StmtsS protocol, validation scope.
- 2026-04-17: Updated NifCursor as shared-pointer wrapper.
- 2026-04-18: Renamed Node to NifCursor, Tree to NifBuilder.
- 2026-06-15: Updated for current `plugins` API: Replacer, `bindSym`, bounded traversal, `copyInto`, source info helpers, and Nimony self-compilation.
