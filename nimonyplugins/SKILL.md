---
name: nimonyplugins
description: Write and debug Nimony plugins for compile-time code generation and DSL rewrites, including plugin-backed templates, `Node` traversal, `Tree` construction, subtree reuse, and source-level plugin errors. Use when replacing Nim macros with Nimony plugins or building a compile-time rewrite in the Nimony plugin system.
---

# Nimony Plugins

Use this skill when writing or reviewing compile-time rewrites for Nimony.
Plugins are the Nimony replacement for macros. For new compile-time DSL rewrites, use a plugin-backed template such as `template foo*(spec: string): untyped {.plugin: "fooplugin".}`. Do not write Nim macros.
Current Nimony may still delegate parts of compilation to Nim, but plugin code should target `nimonyplugins.nim`, not Nim macro APIs.

## Rules

### Setup

1. Resolve the nimony executable: `readlink -f "$(command -v nimony)"`.
2. If the resolved path ends with `/bin/nimony`, open `../src/nimony/lib/nimonyplugins.nim` from there.
3. Otherwise open `src/nimony/lib/nimonyplugins.nim` under the executable's directory.
4. Compile plugin-backed code with `nimony c`.
5. If path resolution needs help, add `--path:` pointing to nimony's `src/` directory.

### End-To-End Shape

6. Expose the rewrite through a public template such as `template foo*(spec: string): untyped {.plugin: "fooplugin".}`.
7. Keep the plugin logic in a separate plugin module.
8. Start the plugin with `let root = loadPluginInput()`.
9. Read the relevant input node, build a `Tree`, then finish with `saveTree(resultTree)` or `saveTree(errorTree("invalid plugin input"))`.
10. Keep runtime helpers in the public module. Keep NIF traversal and code generation in the plugin module.

### Mental Model

11. `Tree` is the mutable copy-on-write builder. Copying a Tree shares the payload; the next mutation detaches it.
12. `Node` is an owned read handle into a frozen snapshot. Copying a Node creates another read handle to the same snapshot.
13. `snapshot(tree)` requires a non-empty tree. Guard with `isEmpty(tree)` first.
14. Treat `Tree` as owned mutable output. Treat `Node` as a stable read cursor.

### Construction

15. `createTree()` creates empty output.
16. `createTree(nkCall, callee, arg1, arg2)` and `createTree(nkCall, info, callee, arg1, arg2)` build a validated node in one call.
17. `withTree(kind, info): body` is the normal way to emit a balanced node.
18. Use manual `addParLe`/`addParRi` only when conditional structure makes `withTree` awkward.
19. Constructed trees are validated. Emit balanced trees with the expected child shape for each tag.
20. Use `NoLineInfo` only for genuinely synthetic output. Preserve source `info` when output is derived from input nodes.

### Traversal

21. `inc(node)` advances one token.
22. `skip(node)` skips the whole current subtree.
23. Do not use `inc` when you mean `skip`.
24. Copy a `Node` for lookahead without committing movement on the original.
25. Use `kind`, `stmtKind`, `exprKind`, `typeKind`, `otherKind`, and `pragmaKind` to inspect the current node.
26. Use `symId`, `symText`, `identText`, `stringValue`, `charLit`, `intValue`, `uintValue`, and `floatValue` to read payload.

### Subtree Reuse

27. `takeTree(t, var node)` copies the current subtree and advances the reader.
28. `addSubtree(t, node)` copies the current subtree without advancing the reader.
29. `add(t, childTree)` appends a whole generated tree.
30. Reuse existing subtrees when they are already correct. Do not rebuild them token by token without a reason.

### Errors And IO

31. Use `errorTree(msg)` for synthetic plugin errors.
32. Use `errorTree(msg, at)` or `errorTree(msg, at, orig)` when location matters.
33. `renderTree(tree)` and `renderNode(node)` are for debugging.
34. `loadPluginInput()` reads the default plugin input from `paramStr(1)`.
35. `saveTree(tree)` writes the default plugin output to `paramStr(2)`.

## Workflow

1. Resolve the real API file.
   Open the `nimonyplugins.nim` used by the exact `nimony` you will run.
2. Decide the public entrypoint.
   Export a template such as `template foo*(spec: string): untyped {.plugin: "fooplugin".}` from the user-facing module.
3. Read the plugin input.
   `loadPluginInput()` gives you the input root as `Node`.
4. Parse before generating when that simplifies the rewrite.
   `smartcli` parses its DSL string into ordinary Nim objects first, then emits the output tree.
5. Build output in one `Tree`.
   Use `withTree`, subtree reuse, and helper procs that append into `var Tree`.
6. Finish explicitly.
   End with `saveTree(resultTree)` or `saveTree(errorTree("invalid plugin input"))`.

## Common Mistakes

| Mistake | Why it's wrong |
|---------|----------------|
| Writing a Nim macro for a new Nimony DSL | Plugins are the compile-time rewrite mechanism in Nimony |
| Mixing the public template and the plugin rewrite logic in one module | It tangles runtime API and NIF generation logic |
| Treating `Tree` as a read cursor | `Tree` is output storage; `Node` is the read handle |
| Using `inc` instead of `skip` on a subtree | `inc` leaves you inside the subtree |
| Confusing `takeTree` with `addSubtree` | One advances the reader and the other does not |
| Snapshotting an empty tree | `snapshot(tree)` asserts on empty input |
| Rebuilding correct input subtrees atom by atom | It is slower, noisier, and easier to get wrong than subtree reuse |
| Crashing on invalid plugin input | Emit `errorTree("invalid plugin input")` so the compiler reports a source-level plugin error |

## References

- `references/minimal_plugin_roundtrip.md` — Small plugin-backed template that works end to end
- `references/smartcli_pattern.md` — Real plugin layout from `smartcli`

## Changelog

- 2026-04-11: Refined the skill around real end-to-end plugin structure. Added plugin-backed template guidance, default `loadPluginInput`/`saveTree` flow, real sample references, and explicit "do not write macros" guidance.
- 2026-04-09: Initial verified skill created from the original `nimonyplugins` guidance.
- 2026-04-09: Refined test-backed guidance for Node lifetime, NIF templates, validation edges, and plugin IO overloads.
