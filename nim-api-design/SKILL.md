---
name: nim-api-design
description: Design clear public Nim APIs for libraries and modules, including exported types, constructors, parameter ownership, lookup functions, error contracts, and container-style interfaces. Use when creating or reviewing a Nim library API, designing an exported module surface, or deciding how callers should construct, pass, access, and validate data.
---

# Nim API Design

## Preamble

Use this skill when designing or reviewing a public Nim API.
Default to plain data, one clear surface, and names that match the standard library.
Reference examples live in `references/`.

## Rules

### Public shape

- Prefer plain `object` types for public data models.
- Use `ref object` only when identity, aliasing, shared mutation, graph structure, or handle lifetime is part of the contract.
- Export one primary public representation per concept.
- Prefer procs, overloads, generics, and iterators. Do not default to methods or runtime dispatch for ordinary APIs.
- Use named `object` types for public semantic data.
- Use tuples only for local glue or iterator yields such as `(key, val)`.
- Reuse stdlib names when the behavior matches: `len`, `contains`/`hasKey`, `[]`, `[]=`, `items`/`mitems`, `pairs`/`mpairs`, `incl`/`excl`, `push`/`pop`.

### Contracts

- Keep constraints in types. Use `Natural`, `Positive`, ranges, enums, sets, and `distinct` types instead of weakening to `int` and re-checking manually.
- Use `distinct` when two values share a base type but must not mix.
- Use `func` for pure query operations when purity is part of the public contract.
- Use `{.raises.}` only when it keeps the public exception surface clear and easy to maintain.

### Constructors and conversions

- Value types use `initX()` and return `T`.
- Ref types use `newX()` and return `ref T`.
- Use one `toX()` name for common conversions. Overload on input type.
- Choose batch parameters by operation: `openArray[T]` for reads, `var openArray[T]` for fixed-length element mutation, and `var seq[T]` for resizing or replacement.
- Keep the zero-argument path simple with sensible defaults.

### Parameter ownership

- Use `T` when the caller's variable stays unchanged, `var T` when the proc changes it, and `sink T` when the proc takes ownership. Use `lent T` only for borrowed returns.
- Pass sink arguments normally. Nim moves proven last-use values and copies others. Use `ensureMove(x)` only to reject a copy at compile time.

### Lookup surface

- Separate required lookup from optional lookup.
- A required lookup raises one specific catchable exception. It does not return a silent default.
- An optional lookup uses an explicit safe path such as `contains`, `hasKey`, `getOrDefault`, or `Option[T]`.
- If several accessors fail the same way, route the failure through one private `{.noinline, noreturn.}` helper.

### Borrowed and mutable access

- Use `lent T` for read accessors that return storage owned by the receiver.
- Return `var T` only when callers may freely modify the value. If changes require validation or related updates, expose mutation procs instead.
- Do not expose scalar `var` accessors such as `var int`, `var bool`, or enum fields from internal state.
- In `lent` and `var` accessors, return directly from storage. Do not route through a temp local.

### Public boundary

- Export only the stable surface. Keep helpers private.
- Use descriptive public names.
- In user code, gate version-specific API with `when (NimMajor, NimMinor) >= (x, y)`. Do not use stdlib-internal `{.since.}`.
- Treat paired value/ref APIs and patterns like `withValue` as opt-in compatibility choices, not defaults.

## Workflow

1. Choose the representation.
   Start with a plain `object`. Switch to `ref object` only if the contract needs identity or aliasing.
2. Name the public types.
   Use named objects for semantic results and `distinct` or range types for domain constraints.
3. Name the constructor surface.
   Use `initX`, `newX`, and `toX` in the stdlib style.
4. Design the lookup surface.
   Provide one strict path for required data and one explicit safe path for optional data.
5. Choose parameter modes and borrowed access.
   Use `T` when the caller's variable stays unchanged, `var T` when the proc changes it, `sink T` when the proc takes ownership, and `lent T` to return a borrow. Use mutation procs when changes need validation or related updates.
6. Verify the contract.
   Compile public examples. Exercise each mutation, ownership, and failure path.

## Common Mistakes

| Mistake | Why it is wrong |
|---------|------------------|
| Starting with `ref object` for plain data | It adds aliasing and shared mutation where the API does not need them |
| Defaulting to methods or runtime dispatch | It hides behavior behind runtime polymorphism when a proc surface is simpler and clearer |
| Weakening `Natural` or `Positive` to `int` and re-checking manually | It throws away a stronger type-level contract |
| Returning a silent default for required data | It hides missing-data bugs |
| Exporting scalar `var` accessors | It leaks mutable internal state |
| Returning `var T` for controlled state | Callers can bypass validation and related updates |
| Returning a `lent` or `var` result through a temp local | ORC rejects the borrow because the temp escapes |
| Using `lent T` for an input parameter | `lent T` is a borrowed return type; the compiler rejects it in parameter position |
| Assuming a sink call always moves the caller's variable | Nim copies the argument when it cannot prove last use |
| Wrapping a routine sink argument in `ensureMove` | Sink already performs last-use analysis; use `ensureMove` only when the code must fail instead of copy |

## References

- `references/representation_default.md` — Plain `object` default and `ref object` only when aliasing is required
- `references/constructors.md` — `initX`, `newX`, and `toX` constructor patterns
- `references/collection_accessors.md` — One coherent container surface with stdlib-style names
- `references/accessor_pair.md` — Minimal borrowed and mutable accessor pair with one shared error helper
- `references/distinct_types.md` — Domain types with `distinct` and borrowed operations
- `references/parameter_and_result_shapes.md` — Parameter defaults, options objects, and named result objects
- `references/parameter_ownership.md` — `T`, `var T`, `sink T`, `lent T`, and explicit ownership transfer
