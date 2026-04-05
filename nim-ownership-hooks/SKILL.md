---
name: nim-ownership-hooks
description: Design, review, and implement Nim ARC/ORC ownership hooks and move semantics for value types, containers, shared handles, and manually allocated storage. Use when Codex works on `=destroy`, `=wasMoved`, `=sink`, `=copy`, `=dup`, `=trace`, `sink` parameters, `lent` accessors, or ARC/ORC ownership bugs and warnings in Nim code.
---

# Nim Ownership Hooks and Move Semantics

Use this skill when editing or reviewing Nim ownership hooks under ARC/ORC.
Start by classifying the type's ownership model, then implement only the hook set that model actually needs, while preserving the codebase's local style.

## Default stance

Most types do **not** need a custom `=destroy`.
Do not write ownership hooks unless the type owns a resource the compiler cannot release on its own.

The compiler auto-manages destruction for primitives, `string`, `seq[T]`, `ref T`, `array`, tuples, closures, and objects whose fields are all auto-managed.
It also lifts hooks through arbitrary nesting: if a field's type already has custom hooks, the enclosing type gets correct compiler-generated hooks for free.

Custom hooks are needed when the type holds a resource the compiler cannot release:
raw pointers (`ptr T`) to manually allocated memory, OS file descriptors or socket handles, distinct types used as handles, or any other non-managed resource.

## Workflow

1. Classify the type.
2. Check whether hooks are already declared and whether declaration order is legal.
3. Choose the minimal correct hook set.
4. Implement the hooks without bypassing child ownership semantics.
5. Verify with focused compile and runtime tests.

## Classify the type first

Choose the hook set from the type's real ownership model before editing anything:

- Plain value or compiler-managed aggregate:
  No custom hooks. The compiler lifts destruction recursively through fields.
- Borrowing or view type:
  Usually no custom hooks. Prefer `lent` results for immutable accessors.
- Move-only owner:
  Implement `=destroy` and `=wasMoved`. This is the common model for manually allocated buffers and other exclusive resources. Add `=sink` only when compiler-generated sink is not acceptable. Mark `=copy` and often `=dup` as `.error.`.
- Deep-owning container:
  Implement `=destroy`, `=wasMoved`, `=copy`, and `=dup`. This is the model for containers that manually allocate backing storage and own their elements. Add `=sink` only when direct field transfer is required by semantics or style.
- Shared or refcounted handle:
  `=copy` and `=dup` usually retain or share a payload instead of deep-copying it.

Do not force one ownership model onto another. A shared handle should not become move-only just because it has a destructor, and a deep-owning container should not pretend copies are cheap shares unless that is the real design.

## Hook signatures

These are the relevant hook shapes:

```nim
proc `=destroy`*(x: T)
proc `=wasMoved`*(x: var T)
proc `=sink`*(dest: var T; src: T)
proc `=copy`*(dest: var T; src: T)
proc `=dup`*(src: T): T
proc `=trace`*(x: var T; env: pointer)
```

Export custom ownership hooks. In this codebase, destructors must be exported. Treat missing export on a custom hook as a bug.

Use `=trace` only for ORC-aware manually allocated containers that can participate in cycles.

## Canonical patterns

### `=destroy`

- Release only resources the object still owns.
- Check the moved-from sentinel first, usually `nil` or a default handle.
- Destroy nested values before freeing raw storage.
- Keep destructor behavior non-raising in practice.
- Remember that proc-typed callbacks called from a destructor may still need `raises: []`.

Canonical shape:

```nim
proc `=destroy`*(x: T) =
  if x.data != nil:
    for i in 0..<x.len:
      `=destroy`(x.data[i])
    dealloc(x.data)
```

### `=wasMoved`

- Reset the fields that make `=destroy` a no-op.
- Set the smallest faithful moved-from state.

Canonical shape:

```nim
proc `=wasMoved`*(x: var T) =
  x.data = nil
```

### `=sink`

- Do not add a custom `=sink` by default.
- The compiler can synthesize sink from `=destroy` plus a raw move, and that is often good enough.
- When a custom `=sink` is required, destroy the destination first and then transfer fields directly.
- Do not add self-assignment checks to `=sink`.
- Do not bypass child hook semantics with `copyMem` or whole-object raw moves unless that behavior is explicitly intended and safe for the type.

Canonical shape:

```nim
proc `=sink`*(dest: var T; src: T) =
  `=destroy`(dest)
  dest.len = src.len
  dest.cap = src.cap
  dest.data = src.data
```

If the destination has fields that are not fully overwritten after `=destroy`, reset it with `=wasMoved(dest)` or assign a default state before rebuilding it.

### `=copy`

- Protect against self-assignment.
- Destroy old destination contents before cloning ownership from the source.
- For move-only types, prefer `{.error.}` instead of inventing partial copy semantics.

Canonical deep-copy shape:

```nim
proc `=copy`*(dest: var T; src: T) =
  if dest.data != src.data:
    `=destroy`(dest)
    `=wasMoved`(dest)
    dest.len = src.len
    dest.cap = src.cap
    if src.data != nil:
      dest.data = cast[typeof(dest.data)](alloc(dest.cap * sizeof(Elem)))
      for i in 0..<dest.len:
        dest.data[i] = src.data[i]
```

Move-only form:

```nim
proc `=copy`*(dest: var T; src: T) {.error.}
```

### `=dup`

- Use `=dup` as an optimized duplication path when `=copy` is custom or expensive.
- For deep-owning containers, `=dup` usually allocates fresh storage and duplicates each live element.
- For shared handles, `=dup` usually retains or increments a reference count.
- Keep the implementation aligned with local style.

Canonical deep-dup shape:

```nim
proc `=dup`*(src: T): T {.nodestroy.} =
  result = T(len: src.len, cap: src.cap, data: nil)
  if src.data != nil:
    result.data = cast[typeof(result.data)](alloc(result.cap * sizeof(Elem)))
    for i in 0..<result.len:
      result.data[i] = `=dup`(src.data[i])
```

### `=trace`

Add `=trace` only when all of these are true:

- the type manually owns storage
- stored values can participate in ORC cycles
- ORC should be able to traverse them

Canonical shape:

```nim
proc `=trace`*(x: var T; env: pointer) =
  if x.data != nil:
    for i in 0..<x.len:
      `=trace`(x.data[i], env)
```

## Move semantics rules that matter in reviews

- A move is an optimized copy when the source is not used afterward.
- `move(x)` forces move semantics.
- `ensureMove(x)` checks that the compiler can prove a move is legal.
- `sink` parameters are affine, not linear:
  the callee may consume the value once, or not at all.
- If the compiler cannot prove an argument to a `sink` parameter is the last use, it may duplicate before passing it.

Important consequence:

- `=copy` needs self-assignment protection.
- `=sink` does not.

Simple self-assignments like `x = x` are removed by the compiler.

## `lent`

Use `lent T` for immutable accessors that should borrow from a container instead of copying.

Example:

```nim
proc `[]`(x: MyContainer; i: int): lent Elem =
  x.data[i]
```

Prefer `lent` over manufacturing cheap-looking copies of owned elements.

## Hook declaration ordering

Custom hooks must be visible before the compiler generates implicit hooks for the type.
Practical triggers include:

- `let` or `var` bindings of the type
- assignments to the type
- function calls returning the type
- sink parameters of the type

Do not declare helper procs that use the type before the hooks if that can trigger hook generation.
When a helper must appear before the hooks:

- Prefer a small `template`.
- Keep it direct.
- Do not stack local alias templates on top of other templates unless it clearly improves the code.

## Common review traps

- Adding custom hooks to a type whose fields are all auto-managed or already have their own hooks.
- Assuming manually owned raw storage is freed automatically because the enclosing object gets destroyed.
- Adding a custom `=sink` when compiler-generated sink was fine.
- Adding self-assignment checks to `=sink`.
- Using `copyMem` or whole-object raw moves in a custom `=sink` and bypassing child hook semantics.
- Forgetting `=wasMoved` for move-only owners.
- Forgetting self-assignment protection in `=copy`.
- Removing `raises: []` from a proc-typed destructor callback without intending to change effects.
- Declaring helper procs before the hooks and triggering the phase-order problem.
- Adding speculative branches such as special zero-count allocation handling without evidence they are needed.
- Rewriting local style while touching hooks:
  if the codebase bans early returns, avoid them;
  if it prefers typed templates without `var`, follow that;
  if it dislikes template aliases, inline the expression.

## Review checklist

- Does the hook set match the type's ownership model?
- Is the type move-only, deep-copying, shared, or borrowing?
- Are hooks declared before first use sites that trigger hook generation?
- Does `=destroy` free only still-owned resources?
- Does `=wasMoved` make `=destroy` a no-op?
- Does custom `=sink` transfer ownership directly without self-assignment checks?
- Does `=copy` protect against self-assignment and preserve semantics?
- Does `=dup` match the ownership model?
- Does `=trace` exist only when ORC cycle traversal actually matters?
- Did the patch preserve the surrounding style?

## Verification after every hook edit

Compile and run the smallest relevant test target immediately after editing hooks.
For container-like types, prefer tests that cover:

- move into another variable
- overwrite of existing owned data
- copy independence
- dup independence
- destroy-after-move
- sink assignment from temporaries

If the compiler emits ARC/ORC warnings, either fix the ownership cause or document why the warning is acceptable in that codebase.
