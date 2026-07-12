---
name: nim-style-guide
description: Write clear, consistent Nim code in a simple stdlib-aligned style, covering imports, naming, proc vs func vs template choices, local variables, constructors, formatting, and control flow. Use when writing new Nim code or reviewing a Nim module for readability, consistency, and low-noise style decisions.
---

# Nim Style Guide

Prefer concise, structured code that the compiler and reader can reason about.

# Rules

## Formatting

- Indent blocks with 2 spaces and use spaces instead of tab characters.
- Keep lines at or below 100 characters.
- Use ordinary spacing instead of aligning columns by hand.
- Write range operators compactly: `a..b`, `a..<b`, and `a..^b`. Add spaces
  when an operand contains an operator, as in `a .. -3`.
- In `range` type constructors, use `..`: `range[0..n-1]` is valid;
  `range[0..<n]` is invalid.
- Indent wrapped declarations, calls, and conditions one extra level.
- Start multiline triple-quoted strings on the next line.

## Imports And Naming

- Use `std/...` imports for stdlib modules.
- Group imports from the same directory: `import std/[a, b, c]`,
  `import lib/[x, y, z]`.
- Use `from foo import bar, baz` when you only need a small API slice.
- `import` brings symbols into scope without qualification.
- Use qualified `module.symbol` access only to resolve genuine name conflicts between imported modules.
- Types use `PascalCase`.
- Procs, funcs, iterators, templates, vars, and fields use `camelCase`.
- Constants may use `camelCase` or `PascalCase`.
- Use `ALL_UPPERCASE` only when preserving names from a C or C++ wrapper.
- Use normal word casing such as `parseUrl` and `httpStatus`.
- Give the most-used representation the base type name. Suffix the others with
  `Obj`, `Ref`, or `Ptr`.
- Suffix catchable exception types with `Error` and programming-bug defect types with `Defect`.
- For non-pure enums, prefix values such as `pcFile`. For pure enums, use `PascalCase`.
- Prefix mutable views with `m`, as in `mitems` and `mpairs`.
- Pair in-place and copied transforms as `reverse` and `reversed`. If the copy
  name already exists, suffix the in-place form with `In`, as in `replaceIn`.
- Name domain predicates subject-first, as in `fileExists`, not `existsFile`.
- Use established stdlib names when behavior matches: `initX`, `newX`, `find`,
  `contains`, `add`, `cmp`, `len`, `cap`, `items`, `pairs`, `incl`, and `excl`.
- Use `find` for a position and `contains` for a `bool`.
- Name a cheap, side-effect-free field getter `foo`. Use `getFoo` when the
  operation has side effects or is not O(1).
- Pair `foo` with `foo=` and `getFoo` with `setFoo`.

## Proc, Func, Template, Macro

- Default to `proc`.
- Use `func` for pure helpers and pure accessors when checked purity helps.
- Use `template` when call-site substitution, lazy evaluation, or a
  control-flow abstraction is required.
- Prefer `proc` and `func` over `method`. Use `method` only when you need runtime dispatch.
- Prefer top-level helpers for reusable logic.
- Use a nested proc when the logic is truly local or when you want a closure.
- A nested proc may capture outer locals. If a nested proc must stay non-capturing, mark it `{.nimcall.}`.
- Use `macro` only when syntax transformation is required.

## Calls, Locals, And Types

- Prefer compact wrapped calls over one-argument-per-line call blocks.
- Use UFCS when it reads like an accessor.
- Use `let` by default.
- Use `var` only for values that mutate.
- Keep local declarations close to first use.
- Keep public and reusable types at module scope.
- Group related fields with the same type when it improves readability.
- Prefer object constructors (`TypeName(field: value)`) over field-by-field
  assignment into an uninitialized `result`.
- Omit fields that should keep their declared defaults.

## Parsing-Sensitive Whitespace

These whitespace choices change how Nim parses code:

- **Attach `[` to a type name.**
  - `array[N, T]` compiles. `array [N, T]` does not.
  - The same applies to `seq[T]`, `Table[K, V]`, etc.

- **Attach `(` to a callable name for a parenthesized call.**
  - `foo(1, 2)` passes two `int` arguments.
  - `foo (1, 2)` passes a single `(int, int)` tuple. Nim treats the parenthesized comma-list as a tuple constructor.

- **Do not use command-call syntax with comparisons or nested calls.**
  - `foo 1 == 1` parses like `foo(1 == 1)`, not `foo(1) == 1`.
  - `outer(inner 1, 1)` parses as `outer(inner(1), 1)`, not `outer(inner(1, 1))`.

- **Use `[:T]` for explicit generic parameters in UFCS calls.**
  - `x.p[:T]()` rewrites to `p[T](x)`.
  - `x.p[T]()` parses as `(x.p)[T]()` and usually means indexing the result.

- **Group negated compound expressions.**
  - Parenthesize compound operands of `not`: `not a or b` parses as `(not a) or b`, so write `not (a or b)` and `not (x < y)`.
  - Write `x notin items`, not `not x in items`.

## Line Continuation

Nim has no line-continuation character. Break expressions after an operator
or comma, or within open delimiters such as `()`, `[]`, and `{}`. Indent the
continued line further than the statement that started it.

For constructs with a body, double indentation can distinguish continuation
lines from the body.

## Control Flow

- Use structured control flow.
- Build the normal return value in `result`.
- When a loop finds the return value, return it directly instead of using a
  flag.
- Do not use `continue`. Put the remaining loop body inside a condition.

# Workflow

1. Pick the callable kind.
   Start with `proc`. Switch to `func` for a useful purity contract, `template`
   for call-site substitution, and `macro` for syntax transformation. Choose
   `method` for runtime dispatch.
2. Write imports and names.
   Use `std/...` imports, narrow imports when practical, and keep names in normal Nim casing.
3. Shape the control flow.
   Use structured control flow. Return directly when a loop finds its result.
4. Clean up locals and constructors.
   Use `let` by default, keep locals near first use, and keep reusable helpers at module scope.
5. Remove noise.
   Remove unused imports, dead helpers, column alignment, and stretched call formatting.

# Common Mistakes

| Mistake | Why it is wrong |
|---------|-----------------|
| Using `method` as the default callable kind | It adds runtime dispatch where a plain `proc` or `func` would usually be clearer. |
| Hiding reusable helpers inside another proc | It makes the helper harder to reuse and easier to turn into an accidental closure. |
| Writing one argument per line by default | It adds vertical noise without adding structure. |
| Using `var` for values that never mutate | It hides which locals actually change. |
| Turning every branch into an early `return` in a multi-step proc | It makes the normal path harder to scan. |
| Using `continue` | A structured branch keeps the loop invariant visible. |

# References

- `references/core_patterns.md`: Simple default patterns for imports, callable kinds, wrapping, locals, and constructors.
- `references/template_usage.md`: Template patterns where a `proc` cannot substitute: scoped cleanup, caller-named access, and lazy evaluation.
