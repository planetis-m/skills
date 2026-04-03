---
name: nim-code-organization
description: Organize Nim modules and orchestration code with clear state ownership and intentional exports.
---

# Nim Code Organization

Use this skill when structuring modules, orchestration flows, helper placement,
or export surfaces in Nim code.

## Core rules

- In orchestration code, avoid nested helper procs that capture mutable outer locals.
- For multi-step orchestration, use outer-scope helper procs and explicit state objects.
- Remove dead imports and dead declarations immediately.
- Keep exports intentional; do not export internals by default.

## Orchestration pattern

Prefer explicit state objects and helper procs over nested closures that depend on mutable outer locals.

## Do

```nim
type
  WriteState = object
    nextToWrite: int

proc flushReady(state: var WriteState; total: int) =
  if state.nextToWrite < total:
    inc state.nextToWrite
```

## Don't

```nim
proc run() =
  let total = 10
  var nextToWrite = 0
  proc flushReady() =
    if nextToWrite < total:
      inc nextToWrite
```

## Review checklist

- Are helper procs capturing mutable outer locals?
- Did this change introduce dead code or dead exports?
- Are imports and exports still intentional after the refactor?
