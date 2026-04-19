---
name: nim-ownership-hooks
description: Implement and review Nim ARC/ORC ownership hooks for types that manually manage resources, including move-only, deep-copy, refcounted, and copy-on-write patterns. Use when a Nim type owns pointers, buffers, file descriptors, or custom heap memory and you need correct `=destroy`, `=copy`, `=dup`, `=sink`, or move semantics.
---

# Nim Ownership Hooks

## 1. Preamble

Use this skill when writing or reviewing Nim ownership hooks under ARC or ORC.

Start by classifying the type's ownership model. Then implement exactly the hook set that model requires — no more, no less. Do not force one ownership model onto another: a shared handle should not become move-only just because it has a destructor, and a deep-owning container should not pretend copies are cheap shares.

Complete examples for each ownership model live in `references/`.

## 2. Rules

### When to write hooks

Do not write hooks unless the type owns a resource the compiler cannot release on its own.

The compiler auto-manages destruction for primitives, `string`, `seq[T]`, `ref T`, `array`, tuples, closures, and objects whose fields are all auto-managed. Hooks lift through nesting: if a field's type already has custom hooks, the enclosing type gets correct compiler-generated hooks for free.

Custom hooks are needed only for non-managed resources: raw pointers (`ptr T`) to manually allocated memory, OS file descriptors, socket handles, `distinct` types whose base has no hooks, or similar. `distinct` types whose base already has hooks lift them automatically.

### Hook-by-hook rules

**`=destroy`**
- Check the moved-from sentinel (`nil` or default handle) before touching fields. Release only resources the type still owns.
- When the type owns raw storage containing elements with their own hooks, destroy each element before freeing the raw storage pointer.
- `=destroy` is implicitly `.raises: []`. Keep destructor behavior non-raising.
- Use the signature `=destroy(x: T)`, not `var T`. Both compile, but `T` prevents accidental field mutation.

**`=wasMoved`**
- Reset every field that `=destroy` checks, so that `=destroy` becomes a no-op on the same variable. For pointer fields, set to `nil`.
- The compiler eliminates a `=destroy` call that follows `=wasMoved` on the same variable.

**`=sink`**
- Do not write a custom `=sink` by default. The compiler synthesizes one from `=destroy` plus a raw move, and that is usually sufficient.
- When a custom `=sink` is required: call `=destroy(dest)`, then `=wasMoved(dest)`, then transfer source fields. No self-assignment check — the compiler eliminates `x = x` before reaching your hook.
- Do not use `copyMem` or whole-object raw moves — they bypass child hook semantics.

**`=copy`**
- Deep-copy types: protect against self-assignment (`if dest.data == src.data: return`). Without it, `x = x` destroys the source before copying.
- After the guard: `=destroy(dest)`, `=wasMoved(dest)`, then rebuild from source. Check that source data is non-nil before allocating.
- For move-only types, use `{.error.}` (bare pragma, no custom message — the compiler ignores custom error strings).
- For refcounted types: `=copy` does destroy-then-share. No pointer self-assignment guard needed — the counter increment balances the destroy.

**`=dup`**
- Deep-owning containers: mark with `{.nodestroy.}` and build a fresh copy. Call `=dup` on each child element (not `copyMem`) so child hooks run.
- Refcounted types: increment the counter and share the pointer. No `{.nodestroy.}` needed — the counter balances the implicit return-path destroy.

**`=trace`**
- Only when all three conditions hold: the type manually owns storage, stored values can participate in ORC cycles, and ORC needs to traverse them.
- Forward-declare `=destroy` and `=trace` alongside each other to prevent the mutual-use generation conflict.

**`lent T`**
- Use `lent T` for immutable accessors that should borrow from a container instead of copying.

### Declaration order

Declare all custom hooks before any proc, converter, iterator, closure, or generic instantiation that mentions the type. The compiler eagerly generates implicit hooks and will error if a custom hook appears afterward.

Safe order: type definition, then `=destroy`, `=wasMoved`, `=copy`, then `=dup`.

Only templates may safely appear between the type definition and the hooks. If a hook body needs a shared helper, write it as a template directly before the hooks.

`importc` procs are opaque and do not trigger implicit hook generation — they may appear before hooks.

### Move semantics

- `move(x)` forces move. Source is left in moved-from state. `=wasMoved` runs on the source.
- `ensureMove(x)` is a compile-time annotation only. Works for rvalues and `sink` parameters. Fails compilation when applied to lvalues with destructors.
- `sink` parameters are affine, not linear: the callee may consume the value once, or not at all.
- Object and tuple fields are separate entities for sink last-use analysis.
- When the compiler cannot prove a sink argument is last use, it inserts `=copy` or `=dup` before passing.

### Edge cases

- **Zero-length allocations**: Guard against `alloc(0)` in constructors and `=copy`. Only allocate when length is positive. `alloc(0)` may return nil or an invalid pointer.
- **Thread-aware allocation**: When a refcounted payload may cross thread boundaries, switch between `allocShared`/`deallocShared` and `alloc`/`dealloc` using `when compileOption("threads")`.

## 3. Workflow

### Step 1: Classify the ownership model

Match the type to exactly one model. Use the hook set that model requires.

| Model | Hooks needed |
|-------|-------------|
| Plain / auto-managed | None |
| Borrowing / view | None. Use `lent T` for accessors. |
| Move-only owner | `=destroy`, `=wasMoved`, `=copy` as `{.error.}` |
| Deep-owning container | `=destroy`, `=wasMoved`, `=copy`, `=dup` |
| Shared / refcounted | `=destroy`, `=wasMoved`, `=dup`, `=copy` |

### Step 2: Implement the minimal hook set

Follow the hook-by-hook rules in section 2. See `references/` for complete examples of each model.

### Step 3: Verify with `--expandArc`

```
nim c --expandArc:nameOfFunction yourfile.nim
```

Confirm the compiler inserts the hooks you expect. Check that synthesized hooks match intent.

### Step 4: Run stress tests

Test these scenarios for every custom-hook type:

- Move into another variable
- Overwrite existing owned data
- Copy independence (mutating copy does not affect original)
- Dup independence
- Destroy-after-move (destroy is a no-op)
- Self-copy (`x = x` does not crash)
- Sink from temporaries
- Zero-length initialization (if the type has constructors)

## 4. Common Mistakes

| Mistake | Why it is wrong |
|---------|-----------------|
| `=destroy` with `var T` | Both compile, but `T` prevents accidental field mutation inside the destructor. |
| Setting fields to nil inside `=destroy` | Use `=wasMoved` for field reset. The compiler eliminates the subsequent destroy. |
| Declaring `=dup` before `=copy` | `=dup` body can trigger implicit `=copy` generation, causing a conflict. |
| Missing self-assignment guard in deep-copy `=copy` | Destroys source data before reading it. |
| Self-assignment check in `=sink` | Compiler already eliminates simple `x = x`. The check is dead code. |
| Missing `{.nodestroy.}` on deep-owning `=dup` | Compiler destroys `result` before the caller receives it. |
| Custom `=sink` when synthesized is fine | Adds unnecessary complexity with no benefit. |
| `copyMem` in `=sink` or `=dup` | Bypasses child hook semantics and breaks the ownership chain for elements that have their own hooks. |
| Missing zero-length guard | `alloc(0)` may return nil; subsequent indexing crashes. |
| `ensureMove` on lvalue with destructor | Compile-time error. Only valid for rvalues and sink params. |
| `alloc` in multi-threaded code | Must use `allocShared`/`deallocShared` instead. |
| Custom error string in `{.error: "msg"}` on `=copy` | The compiler ignores custom error messages. Use bare `{.error.}`. |

## 5. References

- `references/move_only_owner.md` — exclusive resource ownership, no copy allowed
- `references/deep_owning_container.md` — manual allocation with deep copy
- `references/shared_refcounted.md` — refcounted handle (separate counter + generic SharedPtr)
- `references/custom_sink.md` — when and how to write a custom `=sink`

## 6. Changelog

- 2026-04-07: Initial version
- 2026-04-07: Added zero-length guards, non-var destroy preference
- 2026-04-07: Added refcounted nuances from cowstrings analysis
- 2026-04-08: Restructured — examples moved to references/, workflow-focused SKILL.md
- 2026-04-17: Removed cow_string.md (redundant with shared_refcounted.md);
