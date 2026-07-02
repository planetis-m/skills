---
name: nim-defect-analysis
description: Find and classify reliability defects in Nim code using deterministic triage, bounded confirmation, root-cause tracing, and evidence-backed reports. Use when reviewing Nim source for robustness issues in parsers, I/O handlers, FFI boundaries, async code, or ownership hooks, diagnosing unhandled defect paths, or reducing false positives in code-quality findings.
---

# Preamble

Use this skill to review Nim code for robustness and correctness defects. Treat
every finding as a hypothesis until a static trace and, where practical, a small
reproducer support it. Prefer fewer, well-evidenced findings over broad
speculation.

# Rules

## Scope The Review

Review code that processes external input, crosses abstraction boundaries, or
manages resources manually:

- parsing, decoding, deserialization, config/file/network input
- indexing, slicing, integer arithmetic, and size conversions
- allocation and accumulation of `string`, `seq`, buffers, tables, and queues
- async I/O, cancellation, timeouts, shared state, and callbacks
- C FFI, `ptr`, `pointer`, `cstring`, `cast`, `{.emit.}`, manual alloc/free
- custom `=destroy`, `=copy`, `=dup`, `=sink`, and `=wasMoved`
- exception boundaries where `Defect` may escape instead of `CatchableError`

Skip style-only issues, unreachable theoretical defects, and spec disagreements
without credible crash, data-corruption, resource-exhaustion, or
privilege-escalation impact.

## Search High-Signal Risk Sites

Use `rg` first. Useful patterns:

```text
parseInt|parseUInt|parseBiggestInt|parseSaturatedNatural|parseHexInt|parseEnum
split|substr|find|skip|parseUntil|parseWhile|parseUri|parseJson|parseXml
\[[^]]+\]|\.\.|\.\.<|setLen|newString|newSeq|newStringOfCap|add\(
recv|recvLine|recvLineInto|read|readLine|accept|send|Future|async|await
cast\[|addr |ptr |pointer|cstring|alloc|dealloc|copyMem|zeroMem|importc|emit
=destroy|=copy|=dup|=sink|=wasMoved|doAssert|assert|raises:
```

Record only high-value context:

`File:Line | Risk | Reached From | Guard | Candidate Failure`

## Classify Conservatively

| Class | Use when |
|---|---|
| `CONFIRMED` | A reproducer, sanitizer report, fuzz artifact, or integration test demonstrates the failure and root cause. |
| `LIKELY` | Complete static trace shows externally-controlled input reaches a missing guard, but dynamic confirmation is not completed. |
| `LOW` | The static trace, external control, or failure conditions remain incomplete. |
| `FALSE_POSITIVE` | A guard, type constraint, catch boundary, limit, or unreachable path blocks the issue. |
| `NON_DEFECT` | The behavior is a spec mismatch or design choice without credible reliability or robustness impact. |

Never mark a finding `CONFIRMED` from source reasoning alone.
Classification describes evidence, not severity. Assess impact separately.

## Score With Coarse Confidence

Do not multiply pseudo-probabilities.

| Score | Class | Evidence |
|---:|---|---|
| 0.95 | `CONFIRMED` | Reproducer, sanitizer, or fuzz artifact with a root-cause trace. |
| 0.80 | `CONFIRMED` | Deterministic integration test with understood failure conditions. |
| 0.60 | `LIKELY` | Complete static trace without dynamic confirmation. |
| 0.40 | `LOW` | Partial trace or deployment-dependent failure conditions. |
| 0.20 | `LOW` | Speculative path or unclear external control. |
| 0.00 | `FALSE_POSITIVE` or `NON_DEFECT` | The path is blocked or has no reliability impact. |

If two adjacent scores fit, choose the lower score and state the missing
evidence.

## Reduce False Positives

Before reporting, check:

- external-input reachability at the defect site
- reachability under the project build flags and `when defined(...)` branches
- size limits, timeouts, auth checks, enum/range types, and parser guards
- parser consumed-length semantics and whether callers check full consumption
- whether the failure is a `CatchableError` or `Defect` and whether the
  boundary catches it
- whether `-d:danger` changes overflow or assertion behavior
- async cancellation, reentrancy, and shared-state effects
- FFI pointer lifetimes, nullability, struct layout, calling convention, and string ownership
- ownership hook behavior for move-after-destroy, self-copy, zero-length allocation, and destroy-after-move

If a guard blocks the path, report `FALSE_POSITIVE` with the blocking line.

## Require Evidence

Every reported finding needs:

- title, classification, and confidence
- affected file and line
- externally-controlled input or state
- static trace from entry point to failure
- expected vs actual behavior
- root cause
- impact assessment
- reproduction command or reason dynamic reproduction was not completed
- remediation direction

For `CONFIRMED`, also include exact input, commands, observed output, crash,
stack trace, sanitizer report, or saved artifact.

# Workflow

1. **Map the boundary.** Identify target files, entry points, external inputs,
   sensitive operations, and existing guards. Output:
   `Entry | Input Control | Path | Sensitive Operation | Existing Guard`.
2. **Enumerate risk sites.** Use the search patterns above. Keep only sites
   reachable from the boundary.
3. **Generate bounded hypotheses.** Create at most two per risk site. Each must
   name exact input shape, input source, expected behavior, suspected actual
   behavior, and shortest code path.
4. **Complete the static trace.** Verify the entry point, input control, guards,
   catches, limits, consumed lengths, and build-mode branches. If any link is
   missing, downgrade before dynamic confirmation.
5. **Attempt one minimal reproducer.** Prefer direct calls before integration
   tests. Use `doAssert`; do not rely on `assert`. Keep it bounded: one small
   repro file, the shortest failing input, and at most two compile attempts.
6. **Run only relevant modes.** Always start with the default build:

   ```bash
   nim c -r repro.nim
   ```

   Use `--panics:on` for `Defect` termination, release and danger for
   assertion or overflow behavior, and ARC for ownership behavior:

   ```bash
   nim c --panics:on -r repro.nim
   nim c -d:release --stackTrace:on -r repro.nim
   nim c -d:danger --stackTrace:on -r repro.nim
   nim c --mm:arc -r repro.nim
   ```

   State why each additional mode is relevant.
7. **Use sanitizers only for unsafe memory, FFI, or manual allocation.**

   ```bash
   nim c --cc:clang -g -d:noSignalHandler -d:useMalloc \
     --passC:"-fsanitize=address,undefined -fno-omit-frame-pointer" \
     --passL:"-fsanitize=address,undefined -fno-omit-frame-pointer" \
     -r repro.nim
   ```

   `useMalloc` exposes Nim allocations to ASan. `noSignalHandler` lets ASan
   report signal-based crashes.

8. **Use fuzzing or integration tests only when direct reproduction is
   insufficient.** Keep the harness narrow and save inputs, commands, and logs.
9. **Classify and report.** If the reproducer does not confirm the issue,
   downgrade to `LIKELY` or `LOW` and state the missing evidence.

# Common Mistakes

| Mistake | Why it is wrong |
|---|---|
| Marking a source-only claim `CONFIRMED` | Confirmation requires executable evidence. |
| Reporting a risky API call without a reachable externally-controlled path | API presence is not a defect. |
| Ignoring `Defect` vs `CatchableError` | `IndexDefect`, `OverflowDefect`, and `AssertionDefect` can escape ordinary recoverable-error handlers. |
| Using precise-looking probability math | It hides uncertainty and encourages over-claiming. |
| Letting one hypothesis absorb the review | Bounded confirmation keeps the workflow deterministic and forces honest downgrades. |
| Treating `assert` as a reliable guard | `assert` is compiled out in `-d:danger`; use `doAssert` in tests. |
