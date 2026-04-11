---
name: nim-style-guide
description: Write Nim in a simple, stdlib-aligned style with static helpers, clear control flow, and low formatting noise.
---

# Preamble

Use this skill to keep Nim code simple, consistent, and easy to scan.
Larger examples live under `references/`.

# Rules

## Formatting

- Indent with 2 spaces. Do not use tabs.
- Wrap long lines before they become hard to scan.
- Do not align columns with extra spaces.
- Use `a..b` unless spaces are needed for clarity.
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
- Use `template` only for tiny substitutions or tiny syntax wrappers.
- If a helper has its own control flow or mutable local state, make it a `proc` or `func`.
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
- Keep `type` blocks at module scope.
- Group related fields with the same type when it improves readability.
- When using object constructors, set the fields you want to override and omit the fields that should keep their defaults.

## Control Flow

- Prefer straightforward `if/elif/else` and explicit loop conditions.
- Tiny predicate or search helpers may use early `return`.
- In stateful or multi-step procs, keep one clear normal path and use `result = ...` when that reads more clearly.
- Use early `return` for real guard exits or found values, not as the default shape of every branch.
- Do not use `continue`. Restructure the branch instead.

# Workflow

1. Pick the callable kind.
   Start with `proc`. Switch to `func` only for pure helpers. Use `template` or `macro` only when substitution or syntax shaping is the point. Do not use `method` unless you need runtime dispatch.
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
| Using `template` for general helper logic | It hides normal control flow and expands code in place. |
| Using `proc` for an obviously pure helper | It loses a useful compiler-checked purity signal. |
| Writing one argument per line by default | It adds vertical noise without adding structure. |
| Using `var` for values that never mutate | It hides which locals actually change. |
| Turning every branch into an early `return` in a multi-step proc | It makes the normal path harder to scan. |
| Using `continue` | It usually means the branch can be written more clearly. |
| Restating every object field in a constructor | It adds noise and can hide which fields are intentionally overridden. |

# References

- `references/core_patterns.md`: Simple default patterns for imports, callable kinds, wrapping, locals, and constructors.

# Changelog

- 2026-04-11: Refined the guide around Zen of Nim and stdlib defaults. Added explicit guidance for `func` as a checked purity contract and `proc`/`func` over `method` for ordinary helpers. Simplified wording throughout.
- 2026-04-09: Added the in-repo verified `nim-style-guide` skill as a standalone, opinionated style guide.
