---
name: nim-c-wrappers
description: Guidelines for building idiomatic Nim wrappers on top of C FFI bindings.
---

# Nim C Wrappers

This skill covers the two-layer pattern for wrapping C libraries in Nim: a raw FFI layer for ABI correctness and an ergonomic Nim layer for safety and usability. Larger examples live in `references/`.

## Rules

### Architecture

1. Use a **two-layer design**: raw FFI layer (ABI-faithful) + ergonomic Nim layer (safe, idiomatic). Keep the raw layer thin and stable.
2. Split modules by library domain. Mirror the C header structure for large libraries.
3. Centralize shared types in a `lib_raw_types` module to avoid cyclic imports.
4. Export raw symbols only for advanced users; re-export selected symbols from ergonomic modules.

### Raw FFI Layer

5. Use `importc` with `cdecl` (or `stdcall` if the library requires it). Prefer `{.push callconv: cdecl, header: "foo.h".}` blocks for shared conventions.
6. Use `{.header.}` for static linking, `{.dynlib.}` for dynamic linking. Guard library names with `when defined(windows):` etc.
7. **Never reorder struct fields.** Use `object` in C field order. Add `packed` only if C headers specify packing.
8. Use `incompleteStruct` and list only needed fields to reduce ABI risk.
9. For C enums, use **typed integer aliases** (`cint`/`cuint` or `distinct int`) + `const` values. Do not use Nim `enum` in raw bindings.
10. For bitflags, use `distinct` integer types with bitwise helpers. Do not use `set[Enum]`.
11. Map C macros: numeric → `const`; function-like → `inline proc` or `template`; sizeof/side-effect → `template`.
12. Keep pointer types as C intends — do not convert them in the raw layer.

### Type Mapping

| C Type | Nim Type | Notes |
|--------|----------|-------|
| `char` | `cchar` | Platform-dependent signedness |
| `signed char` | `cschar` | Always `int8` |
| `unsigned char` | `uint8` | Safer default spelling; avoid relying on `cuchar` status across Nim versions |
| `short` | `cshort` | Always `int16` |
| `unsigned short` | `cushort` | Always `uint16` |
| `int` | `cint` | Always `int32` |
| `unsigned int` | `cuint` | Always `uint32` |
| `long` | `clong` | ABI-sized (4 on Win64, 8 on LP64) |
| `unsigned long` | `culong` | ABI-sized |
| `long long` | `clonglong` | Always `int64` |
| `unsigned long long` | `culonglong` | Always `uint64` |
| `size_t` | `csize_t` | Alias for `uint` |
| `intptr_t` | `int` | Pointer-sized signed |
| `uintptr_t` | `uint` | Pointer-sized unsigned |
| `float` | `cfloat` | Always `float32` |
| `double` | `cdouble` | Always `float64` |
| `long double` | `clongdouble` | Limited codegen support |
| `void*` | `pointer` | Untyped |
| `T*` | `ptr T` | Nullable |
| `T**` | `ptr ptr T` | |
| `char*` / `const char*` | `cstring` | NUL-terminated |
| `char**` | `cstringArray` | `ptr UncheckedArray[cstring]` |

Struct types: `object` in C order. Fixed arrays: `array[N, T]`. Pointer+length: `ptr T` + `csize_t`. Raw buffers: `ptr UncheckedArray[T]`. Opaque handles: `pointer` or `ptr OpaqueObj` (empty object).

### Ergonomic Layer

13. For **move-only** resources: implement `=destroy`, `=wasMoved`, `=sink`; mark `=copy` and `=dup` with `{.error.}`. Use `ensureMove()` for ownership transfer.
14. For **reference-counted** resources: use a `ptr int` counter. `=copy`/`=dup` increment, `=destroy` decrements and frees at zero. Use field-by-field assignment in `=dup`, not `result = src`.
15. In `=destroy`, explicitly call `=destroy` on owned nested GC-managed fields (string, seq) after releasing C resources.
16. Raise exceptions (IOError, ValueError, etc.) for C errors — do not return result wrappers that only carry ok/kind/message.
17. Do not create custom exception types unless callers handle them differently.
18. Catch errors only at translation boundaries (C return code → Nim exception, or exception → domain result). Let exceptions propagate otherwise.

### Naming

19. Strip redundant C prefixes (LIB_, foo_); keep names that disambiguate or match docs.
20. Keep raw constant names in C style (e.g., `CURLE_OK`).
21. Rename Nim keywords: `type` → `typ`, `addr` → `address`, or use `importc:` to preserve the C name.

### Callbacks

22. Declare callbacks as plain C-callable procs such as `proc onEvent(code: cint; userData: pointer) {.cdecl.}`. Do not pass Nim closures to C.
23. For callback state, use a global table keyed by `userdata`. Ensure Nim data is globally rooted or manually managed.

### Verification

24. Add `static: doAssert sizeof(T) == N` and `offsetOf` checks in tests to verify struct layouts.
25. Test ABI with compile + link + smoke test + runtime checks.

## Workflow

1. **Read the C API.** Identify structs, enums, functions, callbacks, and ownership semantics.
2. **Map types.** Use the type table. Verify sizes with `static: doAssert sizeof`.
3. **Write raw bindings.** One module per C header or subsystem. Centralize shared raw types to avoid cycles. Use `importc`, correct calling convention, `packed` only when C specifies it. Use typed integer aliases for enums.
4. **Write ergonomic wrappers.** Add destructors for owned resources (move-only or RC). Raise exceptions for C errors. Re-export only the intended public surface. Strip prefixes.
5. **Test.** Compile check → link check → smoke test → ABI sizeof/offset asserts → runtime ownership tests.
6. **Iterate.** Add missing APIs as needed. Keep raw layer stable.

## Common Mistakes

| Mistake | Why it's wrong |
|---------|----------------|
| Passing Nim `string` directly to `char*` parameter | Type mismatch; use `.cstring` |
| Using `seq` where C expects stable pointer | `add()` can reallocate, invalidating the pointer |
| Reordering struct fields | Breaks ABI layout, causes garbage values |
| Using Nim `enum` for C enum values | ABI incompatibility; use typed integer aliases |
| Passing closures as C callbacks | C expects plain function pointers, not GC closures |
| Storing `cstring` beyond the call | `cstring` from `string.cstring` dangles after the source is freed |
| `=dup` body using `result = src` in RC pattern | May trigger implicit `=copy` instead of `=dup`; use field-by-field assignment |
| Wrong calling convention | Causes crashes at call sites |

## References

- `references/move_only_resource.md` — Complete move-only resource wrapper with destructor hooks
- `references/rc_resource.md` — Reference-counted (shared ownership) resource wrapper
- `references/callback_registration.md` — C callback registration with rooted userdata state
- `references/enum_and_bitflags.md` — Typed aliases for enums and distinct types for bitflags
- `references/module_layout.md` — Shared-types module plus selective ergonomic re-exports

## Changelog

- 2026-04-09: Initial verified skill created from the original `nim-c-wrappers` guidance.
- 2026-04-09: Refined the verified guidance for dynlib loading, nested destruction, callback userdata registries, and multi-module wrapper layout.
