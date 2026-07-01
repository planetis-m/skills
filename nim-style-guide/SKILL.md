---
name: nim-style-guide
description: Write clear, consistent Nim code in a simple stdlib-aligned style, covering imports, naming, proc vs func vs template choices, local variables, constructors, formatting, and control flow. Use when writing new Nim code or reviewing a Nim module for readability, consistency, and low-noise style decisions.
---

# Preamble

Use this skill to keep Nim code simple, consistent, and easy to scan.
Larger examples live under `references/`.

# Rules

## Formatting

- Indent blocks with 2 spaces and use spaces instead of tab characters.
- Keep lines at or below 80 characters when practical.
- Use ordinary spacing instead of aligning columns by hand.
- Write range operators compactly: `a..b`, `a..<b`, and `a..^b`. Add spaces
  when an operand contains an operator, as in `a .. -3`.
- Indent wrapped declarations, calls, and conditions one extra level.

## Imports And Naming

- Prefer `std/...` imports for stdlib modules.
- Group broad stdlib imports with `import std/[a, b, c]`.
- Use `from std/foo import bar, baz` when you only need a small API slice.
- Types use `PascalCase`.
- Procs, funcs, iterators, templates, vars, and fields use `camelCase`.
- Use normal word casing such as `parseUrl` and `httpStatus`.
- For non-pure enums, prefix values such as `pcFile`. For pure enums, use `PascalCase`.

## Proc, Func, Template, Macro

- Default to `proc`.
- Use `func` for pure helpers and pure accessors when checked purity helps.
- Use `template` when call-site substitution, lazy evaluation, or a
  control-flow abstraction is required.
- Keep ordinary runtime helper logic in a `proc` or `func`.
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
- When using object constructors, set the fields you want to override and omit the fields that should keep their defaults.

## Parsing-Sensitive Whitespace

These whitespace choices change how Nim parses code:

- **Attach `[` to a type name.**
  - `array[0..4, bool]` compiles. `array [0..4, bool]` does not.
  - The same applies to `seq[string]`, `Table[string, int]`, etc.

- **Attach `(` to a callable name for a parenthesized call.**
  - `foo(1, 2)` passes two `int` arguments.
  - `foo (1, 2)` passes a single `(int, int)` tuple. Nim treats the parenthesized comma-list as a tuple constructor.

- **Construct range types with `..`.**
  - `range[0..n-1]` is a range type. `range[0..<n]` is invalid.

## Line Continuation

Nim has no line-continuation character. Break expressions after an operator
or comma, or within open delimiters such as `()`, `[]`, and `{}`. Indent the
continued line further than the statement that started it.

For constructs with a body, double indentation can distinguish continuation
lines from the body.

## Control Flow

- Prefer straightforward `if/elif/else` and explicit loop conditions.
- Tiny predicate or search helpers may use early `return`.
- In stateful or multi-step procs, keep one clear normal path and use `result = ...` when that reads more clearly.
- Use `return` when its control-flow effect is required, such as a guard or
  found value. Prefer the implicit `result` for the normal path.
- Avoid `continue`. Express the condition as a structured branch so the
  invariant remains visible to readers and compiler analysis. Use `continue`
  when restructuring makes the loop less clear.

# Workflow

1. Pick the callable kind.
   Start with `proc`. Switch to `func` for a useful purity contract, `template`
   for call-site substitution, and `macro` for syntax transformation. Choose
   `method` for runtime dispatch.
2. Write imports and names.
   Use `std/...` imports, narrow imports when practical, and keep names in normal Nim casing.
3. Shape the control flow.
   Keep one obvious normal path. Use guard returns only when they make the code simpler.
4. Clean up locals and constructors.
   Use `let` by default, keep locals near first use, keep reusable helpers at module scope, and let constructors keep declaration defaults unless you are overriding them.
5. Remove noise.
   Remove unused imports, dead helpers, column alignment, and stretched call formatting.

# Common Mistakes

| Mistake | Why it is wrong |
|---------|-----------------|
| Using `method` as the default callable kind | It adds runtime dispatch where a plain `proc` or `func` would usually be clearer. |
| Hiding reusable helpers inside another proc | It makes the helper harder to reuse and easier to turn into an accidental closure. |
| Using `template` where ordinary call semantics are sufficient | It expands code at the call site without providing useful substitution, laziness, or control-flow abstraction. |
| Writing one argument per line by default | It adds vertical noise without adding structure. |
| Using `var` for values that never mutate | It hides which locals actually change. |
| Turning every branch into an early `return` in a multi-step proc | It makes the normal path harder to scan. |
| Using `continue` for the ordinary loop path | A structured branch exposes the body's invariant to readers and compiler analysis. |
| Restating every object field in a constructor | It adds noise and can hide which fields are intentionally overridden. |
| Assigning fields into a zero-initialized `result` when the type declares field defaults | Initialize with `TypeName()` first, or use an object constructor, so declared defaults are applied. |

# References

- `references/core_patterns.md`: Simple default patterns for imports, callable kinds, wrapping, locals, and constructors.
