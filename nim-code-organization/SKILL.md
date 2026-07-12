---
name: nim-code-organization
description: Organize Nim modules and multi-step workflows with explicit state ownership, cohesive boundaries, narrow exports, and structured orchestration. Use when refactoring a large Nim file, splitting logic across modules, designing parser-style stateful code, or simplifying nested helpers and hidden mutable state.
---

# Nim Code Organization

Use this skill to make state, invariants, and control flow easy to follow.
Choose the smallest structure that exposes the real workflow.

# Rules

## State ownership

- Use ordinary locals when a workflow fits clearly in one proc.
- When several steps share evolving state or invariants, collect that state in
  a named object and pass it explicitly.
- Start with a plain `object` passed by `var`.
- Choose `ref object` when identity, aliasing, or shared lifetime is part of
  the design.
- Make shared mutation visible in proc parameters and field updates.

## Helper placement

- Extract a helper when it names a meaningful step, is reused, isolates a
  contract, or makes an invariant easier to state.
- Keep a short, one-use sequence in its driver when extraction would only move
  lines elsewhere.
- Put helpers at module scope when several phases use them or they stand on
  their own.
- Use a nested proc for logic local to one caller or for an intentional
  closure.
- A nested proc captures outer locals by default. Mark it `{.nimcall.}` when
  its non-capturing calling convention is required.

## Module boundaries

- Give each module one cohesive responsibility and public contract. A module
  may own several related types or pieces of state.
- Split a module when a part has an independent responsibility, dependency
  set, lifecycle, or reuse boundary.
- Export only the types and entry points callers need.
- Keep orchestration state and helpers private unless another module is meant
  to use them.

## Control flow

- Keep the normal path structured so its invariants remain visible.
- For a closed set of behaviors, represent the kind as data and branch with
  `case`.
- Use `method` when runtime subtype dispatch is part of the design, rather than
  as the default way to divide orchestration steps.

## Stateful module pattern

- For an incremental lifecycle, consider the stdlib parser shape: one state
  object, top-level `open`/`next`/`close`-style procs, and private helpers that
  mutate `var State`.
- Keep lifecycle transitions explicit; each operation should make its state
  requirements and effects apparent.

# Workflow

1. Trace the data flow.
   Identify which values evolve, which steps share them, and which invariants
   must hold between steps.
2. Choose the smallest state scope.
   Use locals for one clear proc, a plain object for shared multi-step state,
   and a reference only for intentional identity or shared lifetime.
3. Shape the helpers.
   Extract meaningful operations. Keep local incidental logic near its caller.
4. Choose module boundaries.
   Group code by responsibility and contract, then split only at a real
   dependency, lifecycle, or reuse boundary.
5. Define the public surface.
   Export the minimum caller-facing types and operations.
6. Choose dispatch.
   Use direct calls and `case` for closed behavior. Introduce runtime dispatch
   for an open subtype-based design.

## State Scope

| Situation | Default shape |
| --- | --- |
| One linear operation | Local values in one proc |
| Several operations share an invariant | Plain state object passed by `var` |
| One caller owns a short captured operation | Nested proc |
| Several phases share a named operation | Module-level proc |
| Identity or shared lifetime is required | `ref object` |

# Common Mistakes

| Mistake | Why it is wrong |
| --- | --- |
| Hiding state shared by several phases in nested captures | The mutation and cross-phase invariants disappear from proc signatures |
| Creating a state type for a short linear calculation | The extra type adds ceremony without clarifying ownership or invariants |
| Extracting every small block into a top-level helper | The reader must jump between names that do not represent meaningful operations |
| Splitting modules by file size alone | File length does not identify a responsibility, dependency, lifecycle, or reuse boundary |
| Using a `method` hierarchy for a closed set of kinds | Static data plus `case` keeps the possible behaviors visible to the compiler and reader |
| Exporting orchestration helpers or state by default | It turns implementation details into a public compatibility obligation |
| Starting with `ref object` for locally owned state | It introduces aliasing and identity that the workflow does not require |

# References

- `references/orchestration_pattern.md` — choose between local closure state
  and explicit multi-step state
- `references/parser_state_pattern.md` — incremental state object with
  top-level mutating procs
