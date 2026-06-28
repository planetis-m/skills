---
name: nimonyplugins
description: Build and debug Nimony compile-time plugins for code generation and DSL rewrites. Use when replacing Nim macros with Nimony plugins, writing or reviewing template, for-loop, module, type, or import plugins, or diagnosing NIF traversal and generated output.
---

# Nimony Plugins

Use Nimony plugins for compile-time rewrites; do not substitute Nim macros.
Plugin modules import `plugins` and are compiled by Nimony itself, not Nim.

## Rules

### Resolve the actual API

- Resolve `nimony` with `readlink -f "$(command -v nimony)"`.
- Open the corresponding `src/nimony/lib/plugins.nim`. Treat it as the source
  of truth because the plugin surface follows `nifcore` semantics.
- A `{.plugin: "path".}` path is relative to the source file containing the
  pragma, not the call site.

### Choose the plugin contract

There are five plugin kinds:

- Template: `template f(...) {.plugin: "p".}` receives
  `(stmts <template-name> <args...>)`. Use `callArgs(root)` to read the
  arguments. Its output is semantically checked again.
- For-loop: `iterator f(...) {.plugin: "p".}` receives
  `(forcall <iterator-name> (callargs ...) (unpackflat|unpacktup ...) <body>)`.
  Use `forLoopCallArgs`, `forLoopVars`, and `forLoopBody`. The body is already
  typed; transformed output is semantically checked again.
- Module: `{.plugin: "p".}` receives the semantically checked full module and
  must return the full module. Output is not checked again.
- Type: `type T {.plugin: "p".} = ...` receives the full module through
  `loadPluginInput()` and triggering definitions through
  `loadTypeDefinitions()`. It must return the full module; output is not
  checked again.
- Import: `import (path/foo) {.plugin: "p".}` transforms an imported module.

When multiple templates or iterators name the same plugin path, use
`pluginName(root)` to dispatch them inside that one executable.

Do not manually decode template or for-loop roots when the named helpers
express the protocol.

### Ownership and identity

- `NifBuilder` is the move-only `nifcore.TokenBuf`. Never copy it.
- `NifCursor` is a copyable, reference-counted, bounded read cursor.
- `snapshot(tree)` borrows a non-empty builder. The cursor keeps its observed
  storage alive; later builder mutation detaches storage as needed.
- Pass completed builders directly to `addTree` and `saveTree`; their `sink`
  parameters handle ownership transfer.
- `SymId` and `TagId` are numeric handles local to shared plugin pools. Resolve
  names with `symText` and `tagText`; `$id` is not a text lookup.
- Plugin inputs and builders use shared preseeded pools, so handles obtained
  from plugin cursors can be reused by builder helpers.

### Build NIF

- `createTree()` creates only an empty builder.
- Use `withTree SomeEnum, info:` for known Nimony enum tags.
- Use balanced `openTree(tag, info)` / `closeTree()` for textual or dynamic
  tags. There is no validated `createTree(kind, children)` overload.
- Use `NoLineInfo` only for synthetic output; preserve `n.info` for derived
  output.
- Use `addTree(dest, child)` for an entire final-use local builder.
- Use `addSubtree(dest, cursor)` to copy without advancing and
  `takeTree(dest, cursor)` to copy and advance.
- Use `copyInto(dest, cursor):` to copy a node head while transforming all
  bounded children.
- Use `bindSym` for hygienic definition-scope symbol references.

### Traverse bounded cursors

- Compound nodes have kind `TagLit`; strings have kind `StrLit`.
- Cursors are bounded by a remaining-token count. There is no exposed closing
  `)` token or `ParRi` sentinel.
- `firstChild(n)` returns a cursor bounded to the current node's children.
- `skip(n)` advances over one atom or complete subtree.
- `into n:` and `loopInto n:` require their bodies to consume all children.
- `balancedTokens n:` visits descendant `TagLit` nodes, excludes the root, and
  leaves `n` advanced past the root.
- Copy a cursor for lookahead. Use `hasMore`, never a closing-token check.

### Prefer Replacer for selective rewrites

- `keep`, `drop`, and `replace` each consume one input child.
- Their kind argument is an assertion, not a filter.
- `keepTag` and `replaceHead` bodies must consume every child.
- `loopKeepTag` preserves a node while iterating its children.
- `peek` restores only the source cursor; writes to `r.dest` persist. Keep
  lookahead read-only.
- Template replacers start at `(stmts <name> <args...>)`; consume or preserve
  the leading name deliberately before processing arguments.

### Report errors and write output

- Return `errorTree(message, at)` for unsupported user input.
- Use assertions only for plugin implementation contract violations.
- `renderNode(cursor)` and `renderTree(builder)` are debugging helpers that
  omit line information.
- `saveTree` consumes a builder. `saveReplacer` writes the replacer output.

## Workflow

1. Resolve and inspect the exact `plugins.nim` used by the selected Nimony.
2. Select the plugin kind and write down its input/output contract.
3. Expose the pragma from a small user-facing module and keep transformation
   logic in a separate plugin module.
4. Load input with `loadPluginInput`, `loadTypeDefinitions`, or `loadReplacer`.
5. Use protocol helpers before traversing arguments, variables, or bodies.
6. Preserve correct subtrees; synthesize only what changes.
7. Return one complete output with `saveTree`, `saveReplacer`, or `errorTree`.
8. Compile plugin integration tests with Nimony. Host Nim may be used only for
   an outer test harness that launches `nimony`.

## Common Mistakes

| Mistake | Correction |
| --- | --- |
| Compiling a plugin module with Nim | Compile it with Nimony |
| Treating a builder as copyable COW state | Builders are move-only; snapshots are stable cursors |
| Using `createTree(kind, children)` | Start empty, then use `withTree` or `openTree`/`closeTree` |
| Looking for `ParLe`, `ParRi`, or `StringLit` | Use `TagLit`, bounded `hasMore`, and `StrLit` |
| Reading the first template child as argument 1 | It is the invoked name; use `callArgs` |
| Reading type definitions with `paramStr(3)` | Use `loadTypeDefinitions()` |
| Appending a builder with `add` | Use consuming `addTree` |
| Comparing `$symId` or `$tagId` to names | Use `symText` or `tagText` |
| Returning only changed statements from module/type plugins | Return the full module |
| Emitting inside `peek` | Output persists even though the source cursor rewinds |

## References

- `references/template_plugin.md` — generate an expression from literal arguments
- `references/replacer_api.md` — rewrite a template call while reusing its argument
- `references/for_loop_plugin.md` — expand an already typed loop body
- `references/module_plugin.md` — selectively rewrite a complete typed module
- `references/type_plugin.md` — validate a module using triggering type symbols
