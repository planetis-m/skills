---
name: nimonyplugins
description: Build and debug Nimony compile-time plugins for code generation and DSL rewrites. Use when replacing Nim macros with Nimony plugins, writing or reviewing template, for-loop, module, type, or import plugins, or diagnosing NIF traversal and generated output.
---

# Nimony Plugins

## Rules

### Resolve the actual API

- Resolve `nimony` with `readlink -f "$(command -v nimony)"`.
- If the resolved path ends in `/bin/nimony`, open
  `../src/nimony/lib/plugins.nim` relative to the executable directory.
  Otherwise open `src/nimony/lib/plugins.nim` under the executable directory.
  Treat that file as the source of truth.
- Plugin modules are compiled with Nimony itself. Each unique plugin path gets
  a separate `nimony c` invocation and cached executable, even when two paths
  contain identical source. Warm builds reuse those executables.
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

Use the named protocol helpers to access template and for-loop inputs.

### Ownership and identity

- `NifBuilder` is the move-only `nifcore.TokenBuf`.
- `NifCursor` is a copyable, reference-counted, bounded read cursor.
- `snapshot(tree)` borrows a non-empty builder. The cursor keeps its observed
  storage alive; later builder mutation detaches storage as needed.
- `addTree` borrows its child builder, so the child remains usable afterward.
  `saveTree` accepts its completed output as a `sink` parameter.
- `SymId` and `TagId` are numeric handles local to shared plugin pools. Resolve
  their names with `symText` and `tagText`.
- Plugin inputs and builders use shared preseeded pools, so handles obtained
  from plugin cursors can be reused by builder helpers.

### Build NIF

- Start a builder with `createTree()`.
- Add known Nimony enum tags with `withTree SomeEnum, info:`.
- Add textual or dynamic tags with balanced `openTree(tag, info)` /
  `closeTree()`.
- Preserve `n.info` when deriving output from an input node. Use `NoLineInfo`
  for synthetic output.
- Use `addTree(dest, child)` to append an entire child builder.
- Use `addSubtree(dest, cursor)` to copy without advancing and
  `takeTree(dest, cursor)` to copy and advance.
- Use `copyInto(dest, cursor):` to copy a node head while transforming all
  bounded children.
- Use `bindSym` for hygienic definition-scope symbol references.
- For each local introduced by a plugin, call `genSym()` once and pass that
  `SymId` to `addSymDef` and every corresponding `addSymUse`.

### Traverse bounded cursors

- Compound nodes have kind `TagLit`; strings have kind `StrLit`.
- Cursors are bounded by a remaining-token count.
- `firstChild(n)` returns a cursor bounded to the current node's children.
- `skip(n)` advances over one atom or complete subtree.
- `into n:` and `loopInto n:` require their bodies to consume all children.
- `balancedTokens n:` visits descendant `TagLit` nodes, excludes the root, and
  leaves `n` advanced past the root.
- Copy a cursor for lookahead and use `hasMore` to test its bounds.

### Prefer Replacer for selective rewrites

- `keep`, `drop`, and `replace` each consume one input child.
- Their kind argument asserts the current child's kind.
- `keepTag` and `replaceHead` bodies must consume every child.
- `loopKeepTag` preserves a node while iterating its children.
- `peek` restores the source cursor; writes to `r.dest` persist.
- Template replacers start at `(stmts <name> <args...>)`; consume or preserve
  the leading name deliberately before processing arguments.

### Report errors and write output

- Return `errorTree(message, at)` when user input violates the plugin's
  contract.
- Reserve assertions for plugin implementation contract violations.
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
7. Build one complete output. Return `errorTree` for invalid input, then write
   the result with `saveTree` or `saveReplacer`.
8. Compile plugin integration tests with Nimony. A host-Nim test harness can
   launch `nimony` when needed.

## Common Mistakes

| Mistake | Correction |
| --- | --- |
| Compiling the plugin module with Nim | Compile plugin modules and integration tests with Nimony |
| Traversing a template root as though every child were an argument | Use `callArgs(root)`; the root also contains the invoked template name |
| Confusing `addSubtree` with `takeTree` | Use `addSubtree` to preserve the cursor position and `takeTree` to advance it |
| Leaving children unconsumed in `into`, `keepTag`, or `replaceHead` | Consume every bounded child in the body |
| Returning a transformed fragment from a module or type plugin | Return the complete module |
| Reusing a textual name for a generated local | Call `genSym()` once and use its `SymId` for the definition and every use |
| Writing output during `peek` while treating it as a dry run | Keep `peek` read-only; it restores the source cursor but not `r.dest` |

## References

- `references/template_plugin.md` — generate an expression from literal arguments
- `references/replacer_api.md` — rewrite a template call while reusing its argument
- `references/for_loop_plugin.md` — expand an already typed loop body
- `references/module_plugin.md` — selectively rewrite a complete typed module
- `references/type_plugin.md` — validate a module using triggering type symbols
- `references/generated_symbols.md` — introduce a collision-free local symbol
