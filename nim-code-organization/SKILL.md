---
name: nim-code-organization
description: Organize Nim code into clear modules and multi-step workflows, with explicit state, top-level helper procs, narrow exports, and easy-to-follow orchestration. Use when refactoring a large Nim file, splitting logic across modules, designing parser-style stateful code, or cleaning up nested helpers and hidden mutable state.
---

# Nim Code Organization

## Preamble

Use this skill when splitting Nim code into modules, helpers, and orchestration steps.
Keep shared state explicit. Keep behavior in top-level `proc`s. Keep exports narrow.

## Rules

### Orchestration state

- For multi-step orchestration, use an explicit state object.
- Prefer a plain `object` passed by `var` for orchestration state.
- Use `ref object` state only when identity, aliasing, or shared lifetime is part of the design.
- Pass shared mutable flow through proc parameters. Do not hide it in outer locals.

### Helper placement

- Prefer top-level helper procs for orchestration logic.
- Keep reusable helpers out of the main driver proc.
- Use nested procs only for truly local logic or intentional closures.
- A nested proc may capture outer locals by default. If a nested proc must stay non-capturing, mark it `{.nimcall.}`.

### Module shape

- Keep exports intentional. Export only the public surface.
- Keep orchestration internals, helper procs, and state details private unless another module must call them.
- Keep one module focused on one piece of state and the procs that operate on it.

### Control flow

- Prefer explicit branching in `proc`s over runtime dispatch for ordinary orchestration code.
- When behavior varies by kind, model the kind in data and branch with `case` before reaching for `method`.

### Stdlib pattern

- Follow the stdlib parser-style shape when it fits: one state object, top-level `open`/`next`/`close`-style procs, and private helpers that mutate `var State`.

## Workflow

1. Identify the shared mutable flow.
   If several steps touch the same evolving state, name it as an explicit object.
2. Choose the state representation.
   Start with a plain `object` and pass it by `var`.
3. Place helpers.
   Put orchestration helpers at module scope. Use nested procs only when the logic is local and short.
4. Define the public surface.
   Export only the entry points and public data types.
5. Choose the control flow shape.
   Use a small set of procs and explicit branching. Add runtime dispatch only if the design really needs it.

## Minimal Pattern

```nim
type
  State = object
    pos: int
    ready: seq[bool]

proc markReady(state: var State; idx: int) =
  state.ready[idx] = true

proc flushReady(state: var State; ids: openArray[string]; out: var seq[string]) =
  while state.pos < ids.len and state.ready[state.pos]:
    out.add ids[state.pos]
    inc state.pos
```

## Common Mistakes

| Mistake | Why it's wrong |
|---------|----------------|
| Hiding shared orchestration flow in outer locals | The data flow becomes implicit instead of visible in proc signatures |
| Using nested helper captures for a multi-step pipeline | It hides shared mutation and makes the control flow harder to inspect |
| Spreading one stateful workflow across many runtime-dispatched types | The state flow becomes harder to follow than a small set of procs and a `case` split |
| Exporting internal helpers or internal state | It leaks implementation details into the public API |
| Starting with `ref object` state for a plain local pipeline | It adds aliasing where a plain `object` would keep ownership clearer |

## References

- `references/orchestration_pattern.md` — Explicit state object vs nested closure for a small orchestration flow
- `references/parser_state_pattern.md` — Stdlib-style parser/state object with top-level mutating procs

## Changelog

- 2026-04-09: Initial verified skill.
- 2026-04-11: Added plain-object state, top-level orchestration, nested proc capture guidance.
