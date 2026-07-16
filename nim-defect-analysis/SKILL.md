---
name: nim-defect-analysis
description: Find reliability and security defects in Nim code. Use when reviewing Nim source for bugs, auditing parsers or protocol handlers for crashes, checking FFI or ownership code for memory safety, or reducing false positives in code review findings.
---

# Nim Defect Analysis

A finding is real when you can demonstrate it; until then it is a hypothesis. Focus on finding and confirming defects, not on elaborate triage mechanics.

# Rules

## Look Broadly

Review the code for correctness and reliability defects. Do not restrict
attention to a fixed checklist of patterns or API names. Common bug sites
include:

- parsing, decoding, deserialization, and any external input handling
- indexing, slicing, integer arithmetic, and size conversions
- allocation and accumulation in `string`, `seq`, buffers, tables, and queues
- async I/O, cancellation, shared state, and callbacks
- C FFI, `ptr`, `cstring`, `cast`, `{.emit.}`, manual allocation
- custom `=destroy`, `=copy`, `=dup`, `=sink`, and `=wasMoved`
- exception boundaries where `Defect` may escape `CatchableError` handlers
- logic errors, off-by-one, wrong conditions, missing cases

This list is illustrative, not exhaustive. If something looks wrong, investigate
it regardless of whether it matches a known pattern.

## Search Efficiently

Use `rg` to locate risky operations quickly — parsing functions, allocation,
pointer operations, casts, FFI imports, ownership hooks. But also read the code
to understand its logic. Many bugs are logic errors that no pattern search will
find.

## Trace Across Function Boundaries

Most false positives and false negatives come from incomplete cross-function
reasoning. Do not stop at the function where a risky operation sits.

When a function calls another function with external input:

- Read the callee. Does it validate, bounds-check, or truncate the input?
- Check what the callee returns. Does it return a consumed length, a partial
  result, or an error code the caller might ignore?
- Trace the data path through every intermediate function, not just the entry
  point and the crash site.
- Read type definitions and `when defined(...)` branches that affect the path.

If you cannot trace the full path from input to failure, you do not have a
complete trace. Say so and mark the finding `SUSPECTED`.

## Classify By Evidence, Not Feelings

Use four classes. They describe what you have done, not how confident you feel.

| Class | Means |
|---|---|
| `CONFIRMED` | A reproducer, sanitizer, or test demonstrates the failure. |
| `TRACED` | Complete static trace from external input to the failure, but no reproducer yet. |
| `SUSPECTED` | Partial trace or unclear control flow. Something looks wrong but the path is not fully verified. |
| `FALSE_POSITIVE` | A guard, type constraint, catch boundary, or unreachable path blocks the issue. |

Do not assign numbers. Do not invent probability or confidence scores. State
what you found and what evidence you have.

## Test Guards, Do Not Debate Them

If you are unsure whether a guard blocks a path, write a reproducer that tests
it. Do not spend time reasoning about whether a guard is sufficient when a
three-line test can settle it.

Common guard questions a reproducer can answer:

- Does `except CatchableError` catch this exception? `Defect` subclasses
  (`IndexDefect`, `OverflowDefect`, `AssertionDefect`) are not caught by it.
- Does `-d:danger` change the behavior? `assert` and range checks are disabled;
  `doAssert` remains active.
- Does a bounds check, limit, range conversion, or parser guard actually block
  the input shape you are testing?
- Does a consumed-length parser leave trailing input unvalidated?

## Use Compiler And Runtime As Primary Evidence

Compiler output, runtime behavior, and sanitizer reports are stronger evidence
than pure reasoning. The hybrid approach — use tools, then reason about their
output — produces fewer false positives than reasoning alone.

Build and run reproducers with `nim c -r`. Use `doAssert` for assertions, not
`assert` — `assert` is compiled out under `-d:danger`.

Default build:

```bash
nim c -r repro.nim
```

Additional modes when the bug depends on them:

```bash
nim c --panics:on -r repro.nim        # Defect termination behavior
nim c -d:danger -r repro.nim          # Overflow and assertion behavior
nim c --mm:arc -r repro.nim           # Ownership and hook behavior
```

Sanitizers for unsafe memory, FFI, or manual allocation:

```bash
nim c --cc:clang -g -d:noSignalHandler -d:useMalloc \
  --passC:"-fsanitize=address,undefined -fno-omit-frame-pointer" \
  --passL:"-fsanitize=address,undefined -fno-omit-frame-pointer" \
  -r repro.nim
```

`useMalloc` exposes Nim allocations to ASan. `noSignalHandler` lets ASan report
signal-based crashes.

## Check For Guards

Before reporting, verify whether the path is actually reachable:

- Does external input reach the defect site?
- Is there a bounds check, limit, range type, or parser guard?
- Does a `catch` boundary catch the exception? `Defect` subclasses
  (`IndexDefect`, `OverflowDefect`, `AssertionDefect`) are not caught by
  `except CatchableError`.
- Does `-d:danger` change the behavior?
- Are there `when defined(...)` branches that affect the path?
- For parser defects: check whether functions that return a consumed length
  leave trailing input unvalidated.
- For FFI defects: check pointer lifetime, nullability, struct layout, calling
  convention, and string ownership.
- For ownership-hook defects: check move-after-destroy, self-copy, zero-length
  allocation, and destroy-after-move.

If a guard blocks the path, report `FALSE_POSITIVE` with the blocking line.

## Report Concisely

Each finding needs:

- file and line
- what is wrong
- how input reaches it
- expected vs actual behavior
- evidence: reproducer command and output for `CONFIRMED`, complete static
  trace for `TRACED`, partial trace and what is missing for `SUSPECTED`,
  blocking guard for `FALSE_POSITIVE`
- remediation direction

Keep the report short. Prefer a few well-evidenced findings over many
speculative ones.

# Workflow

1. **Read the code.** Understand what it does, where input enters, and where
   sensitive operations happen. Read callee functions and type definitions, not
   just the entry point. Look for anything that could go wrong.
2. **Trace candidate defects.** For each suspicious site, trace the full path
   from input to the operation across function boundaries. Check for guards
   along the way. If you cannot complete the trace, mark it `SUSPECTED` and say
   what is missing.
3. **Write a minimal reproducer.** Confirm the bug with the smallest possible
   input. If a guard's sufficiency is unclear, test it with a reproducer
   instead of debating it. If you cannot reproduce a traced finding, keep it as
   `TRACED` and state what is missing.
4. **Report.** List `CONFIRMED` findings with reproducer evidence, `TRACED`
   findings with their complete static traces, `SUSPECTED` findings with what
   is missing, and `FALSE_POSITIVE` findings with the blocking guard.

# Common Mistakes

| Mistake | Why it is wrong |
|---|---|
| Marking a source-only claim `CONFIRMED` | Confirmation requires executable evidence. |
| Stopping the trace at the function with the risky API | Most false positives come from not reading callees and cross-function data flow. |
| Debating whether a guard blocks a path instead of testing it | A three-line reproducer settles it faster and more reliably. |
| Reporting a risky API call without a reachable path | API presence is not a defect. |
| Ignoring `Defect` vs `CatchableError` | `IndexDefect`, `OverflowDefect`, and `AssertionDefect` escape ordinary handlers. |
| Treating `assert` as a reliable guard | `assert` is compiled out in `-d:danger`; use `doAssert` in tests. |
| Assigning numerical confidence scores | Numbers add false precision without improving the analysis. |

## References

No reference files.
