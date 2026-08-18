---
name: nim-api-design
description: Design clear public Nim APIs for libraries and modules, including exported types, constructors, parameter ownership, lookup functions, error contracts, and container-style interfaces. Use when creating or reviewing a Nim library API, designing an exported module surface, or deciding how callers should construct, pass, access, and validate data.
---

# Nim API Design

## Rules

### Public shape

- Prefer plain `object` types for public data models.
- Use `ref object` only when identity, aliasing, shared mutation, graph structure, or handle
  lifetime is part of the contract.
- Export one primary public representation per concept. Add paired value/ref APIs only when both
  forms are part of the contract.
- Prefer procs, overloads, generics, and iterators. Do not default to methods or runtime dispatch
  for ordinary APIs.
- Use named `object` types for public semantic data.
- Use tuples only for local glue or iterator yields such as `(key, val)`.
- Reuse stdlib names when the behavior matches: `len`, `find`, `contains`/`hasKey`, `[]`, `[]=`,
  `items`/`mitems`, `pairs`/`mpairs`, `add`, `del`, `clear`, `incl`/`excl`, and `push`/`pop`.
- When indexed removal must preserve sequence order, use `delete(idx)`, not `del(idx)`.
- Use `find` for an index or position result. Use `contains` or `hasKey` for boolean membership.
- For collection-like types, expose `items` and `pairs`. Add `mitems` and `mpairs` only when
  callers may safely mutate yielded values.
- For comparable types, define `==`, `<` and `<=`. Do not define `!=`, `>`, or `>=`; Nim derives them.

### Contracts

- Use range types for constrained public parameters; store their values in the underlying type
  (`int` for `Natural` or `Positive`).
- Pass arguments directly to range parameters; conversion is implicit, so do not write `Positive(x)`.
- Model closed choice sets as enums; add reserved members for future assignments in bounded
  protocol code spaces; use strings for open-ended or externally extensible token namespaces.
- When an enum's string spelling is dictated by an external format or protocol, set
  explicit strings (`dirNorth = "north"`); `$` and `parseEnum[T]` always round-trip.
- Use `static[T]` in public APIs only when callers must supply a compile-time constant.
- Bare `typedesc` parameters may name different types; share `T` across `typedesc[T]` parameters
  when they must match.
- Use `distinct` when two values share a base type but must not mix.
- If a public type can be used as a table or set key, define `hash` consistent with `==`.
- Use `func` for pure query operations when purity is part of the public contract.
- Use `{.raises: [].}` when a proc must not raise. Leave raising procs unannotated.

### Constructors and conversions

- Use `initX()` for value types that copy by value.
- Use `newX()` for ref types and for value types with reference semantics.
- Use one `toX()` name for common conversions. Overload on input type. Do not define converters.
- Use default parameter values for optional constructor arguments, keeping the no-argument call
  the main path.

### Sequence parameters

- When a parameter must accept both arrays and seqs, use `openArray[T]` for read-only
  traversal or `var openArray[T]` for fixed-length element mutation.
- Resizing or replacement requires `var seq[T]`: an `openArray` is fixed-length.
- When you control the callers, name the concrete type (`array[N, T]` or `seq[T]`) 
  instead of `openArray[T]`.

### Parameter ownership

- Use `T` when the caller's variable stays unchanged, `var T` when the proc changes it, `sink T`
  when the proc takes ownership, and `lent T` only for borrowed returns.
- Passing `x: T` never copies what `x` points to. Do not use `ptr T` or `addr x` to avoid a copy.
- Pass sink arguments normally — do not wrap them in `move()` or `ensureMove()`. Last-use
  auto-sink moves locals, their fields, tuple fields and indices, and direct-indexed seq/array
  elements with no copy.
- Use `move(x)` only where auto-sink does not apply: fields of `var` parameters, loop-indexed
  seq/array elements (`arr[i]`), and values reused later in the same scope.
- Use `ensureMove(x)` to make an accidental copy a compile-time error.

### Lookup surface

- Separate required lookup from optional lookup.
- A required lookup raises one specific catchable exception. It does not return a silent default.
- Use `contains` or `hasKey` for membership checks and `getOrDefault` for explicit fallback values.
- If several accessors fail the same way, route the failure through one private
  `{.noinline, noreturn.}` helper.

### Borrowed and mutable access

- Use `lent T` for read accessors that return storage owned by the receiver.
- Return `var T` only for deliberate mutable views. If changes require validation or related
  updates, expose mutation procs instead.
- In `lent` and `var` accessors, return directly from storage. Do not route through a temp local.

### Public boundary

- Export only the stable surface. Keep helpers private.
- Keep accessor-backed fields private, so external dot access routes to the
  accessors; an exported field would bypass them.
- Use descriptive public names.
- In user code, gate version-specific API with `when (NimMajor, NimMinor) >= (x, y)`.
- Keep template lookup escape hatches such as `withValue` secondary to the main lookup surface.

## Workflow

1. Choose the representation.
   Start with a plain `object`. Switch to `ref object` only if the contract needs identity or aliasing.
2. Name the public types.
   Use named objects for semantic results and `distinct` types for domain identities.
3. Name the constructor surface.
   Use `initX`, `newX`, and `toX` in the stdlib style.
4. Design the lookup surface.
   Provide one strict path for required data and one explicit safe path for optional data.
5. Choose parameter modes and borrowed access.
   Use `T` when the caller's variable stays unchanged, `var T` when the proc changes it, `sink T`
   when the proc takes ownership, and `lent T` to return a borrow. Use mutation procs when changes
   need validation or related updates.
6. Verify the contract.
   Compile public examples. Exercise each mutation, ownership, and failure path.

## Common Mistakes

| Mistake | Why it is wrong |
|---------|------------------|
| Starting with `ref object` for plain data | It adds aliasing and shared mutation where the API does not need them |
| Defaulting to methods or runtime dispatch | It hides behavior behind runtime polymorphism when a proc surface is simpler and clearer |
| Weakening a constrained public parameter to `int` and re-checking manually | It throws away a stronger boundary contract |
| Returning a silent default for required data | It hides missing-data bugs |
| Returning `var T` for controlled state | Callers can bypass validation and related updates |
| Returning a `lent` or `var` result through a temp local | The temp dies at return; the compiler rejects the dangling borrow |
| Using `lent T` for an input parameter | `lent T` is a borrowed return type; the compiler rejects it in parameter position |
| Assuming a sink call always moves the caller's variable | Nim copies the argument when it cannot prove last use |
| Wrapping a routine sink argument in `ensureMove` | Sink already performs last-use analysis; use `ensureMove` only when the code must fail instead of copy |
| Defining `!=`, `>`, or `>=` for a type | These override Nim's derived comparison templates and can make comparisons inconsistent |

## References

- `references/representation_and_construction.md` — Choosing value or reference semantics with
  `initX` and `newX` construction.
- `references/lookup_and_mutation.md` — Collection access through required, optional, borrowed,
  and controlled-mutation paths.
- `references/parameter_and_result_shapes.md` — Domain IDs, related options, constrained
  parameters, and named results in one public API.
- `references/parameter_ownership.md` — Choosing `openArray`, `var`, `sink`, and `lent` parameters.
- `references/template_usage.md` — Templates for scoped cleanup, caller-named access, and lazy
  evaluation that a proc cannot express.
