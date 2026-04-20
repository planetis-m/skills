---
name: nimonyplugins
description: Write and debug Nimony plugins for compile-time code generation and DSL rewrites, including plugin-backed templates, `NifCursor` traversal, `NifBuilder` construction, subtree reuse, and source-level plugin errors. Use when replacing Nim macros with Nimony plugins or building a compile-time rewrite in the Nimony plugin system.
---

# Nimony Plugins

Use this skill when writing or reviewing compile-time rewrites for Nimony.
Plugins are the Nimony replacement for macros. For new compile-time DSL rewrites, use a plugin-backed template such as `template foo*(spec: string): untyped {.plugin: "fooplugin".}`. Do not write Nim macros.
Current Nimony may still delegate parts of compilation to Nim, but plugin code should target `nimonyplugins.nim`, not Nim macro APIs.

## Rules

### Setup

- Resolve the nimony executable: `readlink -f "$(command -v nimony)"`.
- If the resolved path ends with `/bin/nimony`, open `../src/nimony/lib/nimonyplugins.nim` from there.
- Otherwise open `src/nimony/lib/nimonyplugins.nim` under the executable's directory.
- Plugin modules are compiled with Nim 2, not Nimony. The compiler invokes `nim c -d:nimonyPlugin plugin.nim` and caches the result.
- The plugin path in `{.plugin: "path"}` is relative to the directory of the source file that contains the pragma, not the call site.

### Plugin Kinds

There are three kinds of plugins. All share the same `nimonyplugins` API.

- **Template plugin**: `template foo(...) {.plugin: "path".}` — invoked at each call site. The input is wrapped in a `StmtsS` node containing the arguments. Skip it with `if n.stmtKind == StmtsS: inc n`.
- **Module plugin**: `{.plugin: "path".}` as a top-level statement — receives the entire module after semantic analysis. Must output the complete transformed module.
- **Type plugin**: `type T {.plugin: "path".} = ...` — invoked for every module that uses `T`. Receives two inputs: `paramStr(1)` for the module AST and `paramStr(3)` for the type definition.

### End-To-End Shape

- Expose the rewrite through a public template such as `template foo*(spec: string): untyped {.plugin: "fooplugin".}`.
- Keep the plugin logic in a separate plugin module.
- Start the plugin with `let root = loadPluginInput()`. For type plugins, also load `loadPluginInput(paramStr(3))` for the triggering type definitions.
- Read the relevant input node, build a `NifBuilder`, then finish with `saveTree(resultTree)` or `saveTree(errorTree("invalid plugin input"))`.
- Keep runtime helpers in the public module. Keep NIF traversal and code generation in the plugin module.
- Template plugins can be hidden inside imported modules so callers do not see the `.plugin` pragma.

### Mental Model

- `NifBuilder` is the mutable COW builder. Copying a NifBuilder shares the payload; the next mutation detaches it.
- `NifCursor` wraps a `Cursor`, which is a reference-counted shared pointer into token data. Copying a NifCursor increments the refcount. NifCursors keep data alive even after the source NifBuilder is destroyed.
- `snapshot` takes `var NifBuilder` (borrows, does not consume). It calls `beginRead` under the hood, which shares buffer ownership. The tree stays writable; mutation detaches the buffer via COW.
- `snapshot` requires a non-empty tree. Guard with `isEmpty(tree)` first.
- Treat `NifBuilder` as owned mutable output. Treat `NifCursor` as a stable read handle that independently owns its data.

### Construction

- `createTree()` creates empty output.
- `createTree(nkCall, callee, arg1, arg2)` and `createTree(nkCall, info, callee, arg1, arg2)` build a validated node in one call.
- `withTree(kind, info): body` is the normal way to emit a balanced node.
- Use manual `addParLe`/`addParRi` only when conditional structure makes `withTree` awkward.
- `createTree(kind, children...)`, `%~`, and `nifFragment` produce validated trees. If the structure is wrong, the result is replaced with an `ErrT` node. Trees built via `withTree` or `addParLe`/`addParRi` are not validated.
- Use `NoLineInfo` only for genuinely synthetic output. Preserve source `info` when output is derived from input nodes.

### Traversal

- `inc(node)` advances one token.
- `skip(node)` skips the whole current subtree.
- Do not use `inc` when you mean `skip`.
- Copy a `NifCursor` for lookahead without committing movement on the original.
- Use `kind`, `stmtKind`, `exprKind`, `typeKind`, `otherKind`, and `pragmaKind` to inspect the current node.
- Use `symId`, `symText`, `identText`, `stringValue`, `charLit`, `intValue`, `uintValue`, and `floatValue` to read payload.

### Subtree Reuse

- `takeTree(t, var node)` copies the current subtree and advances the reader.
- `addSubtree(t, node)` copies the current subtree without advancing the reader.
- `add(t, childTree)` appends a whole generated tree.
- Reuse existing subtrees when they are already correct. Do not rebuild them token by token without a reason.

### NIF Templates

- `%~` parses a NIF template string with `$name` substitutions from a bindings table.
- `nifFragment(str)` parses a literal NIF fragment string into a NifBuilder. Use it when there are no substitutions.
- `$$` produces a literal dollar sign inside a NIF template.
- The `~` operator converts values to NifBuilder fragments: `~node` copies the subtree, `~"str"` makes a string literal, `~ident("name")` makes an identifier, `~42` makes an integer literal, `~-14` makes a float literal, `~'x'` makes a char literal, `~true`/`~false` makes a boolean node, `~tree` passes a NifBuilder through unchanged.

### Errors And IO

- Use `errorTree(msg)` for synthetic plugin errors.
- Use `errorTree(msg, at)` or `errorTree(msg, at, orig)` when location matters.
- `renderTree(tree)` and `renderNode(node)` are for debugging.
- `loadPluginInput()` reads the default plugin input from `paramStr(1)`.
- `saveTree(tree)` writes the default plugin output to `paramStr(2)`.

## Workflow

1. Resolve the real API file.
   Open the `nimonyplugins.nim` used by the exact `nimony` you will run.
2. Decide the public entrypoint.
   Export a template such as `template foo*(spec: string): untyped {.plugin: "fooplugin".}` from the user-facing module.
3. Read the plugin input.
   `loadPluginInput()` gives you the input root as `NifCursor`.
4. Parse before generating when that simplifies the rewrite.
   `smartcli` parses its DSL string into ordinary Nim objects first, then emits the output tree.
5. Build output in one `NifBuilder`.
   Use `withTree`, subtree reuse, and helper procs that append into `var NifBuilder`.
6. Finish explicitly.
   End with `saveTree(resultTree)` or `saveTree(errorTree("invalid plugin input"))`.

## Common Mistakes

| Mistake | Why it's wrong |
|---------|----------------|
| Writing a Nim macro for a new Nimony DSL | Plugins are the compile-time rewrite mechanism in Nimony |
| Mixing the public template and the plugin rewrite logic in one module | It tangles runtime API and NIF generation logic |
| Treating `NifBuilder` as a read cursor | `NifBuilder` is output storage; `NifCursor` is the read handle |
| Using `inc` instead of `skip` on a subtree | `inc` leaves you inside the subtree |
| Confusing `takeTree` with `addSubtree` | One advances the reader and the other does not |
| Assuming a NifCursor is invalidated when its source NifBuilder is mutated or destroyed | The Cursor refcount keeps the data alive; NifBuilder mutation detaches the buffer via COW |
| Snapshotting an empty tree | `snapshot(tree)` asserts on empty input |
| Rebuilding correct input subtrees atom by atom | It is slower, noisier, and easier to get wrong than subtree reuse |
| Crashing on invalid plugin input | Emit `errorTree("invalid plugin input")` so the compiler reports a source-level plugin error |
| Assuming `withTree` output is validated | Only `createTree(kind, children)`, `%~`, and `nifFragment` validate; `withTree` and `addParLe`/`addParRi` do not |

## References

- `references/template_plugin.md` — Template plugin: compile-time 256-element popcount lookup table
- `references/module_plugin.md` — Module plugin: strip top-level debug blocks
- `references/type_plugin.md` — Type plugin: field-aware passthrough with paramStr(3)

## Changelog

- 2026-04-09: Initial skill.
- 2026-04-11: Added plugin-backed templates, loadPluginInput/saveTree flow.
- 2026-04-15: Added plugin kinds, Nim 2 compilation, StmtsS protocol, validation scope.
- 2026-04-17: Updated NifCursor as shared-pointer wrapper.
- 2026-04-18: Renamed Node to NifCursor, Tree to NifBuilder.
