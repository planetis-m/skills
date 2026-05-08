---
name: nim-vuln-discovery
description: Find security vulnerabilities in Nim codebases with deterministic triage, bounded confirmation attempts, exploitability analysis, and evidence-backed reports. Use when auditing Nim source, reviewing parser/I/O/FFI/async/ownership attack surfaces, validating suspected bugs, or reducing false positives in Nim security findings.
---

# Preamble

Use this skill to audit Nim code for security bugs. Treat every finding as a
hypothesis until a static trace and, where practical, a small reproducer support
it. Prefer fewer, well-evidenced findings over broad speculation.

No external reference files are required; the workflow is self-contained.

# Rules

## Scope The Audit

Audit code that processes untrusted input, crosses a trust boundary, or manages
resources manually:

- parsing, decoding, deserialization, config/file/network input
- indexing, slicing, integer arithmetic, and size conversions
- allocation and accumulation of `string`, `seq`, buffers, tables, and queues
- async I/O, cancellation, timeouts, shared state, and callbacks
- C FFI, `ptr`, `pointer`, `cstring`, `cast`, `{.emit.}`, manual alloc/free
- custom `=destroy`, `=copy`, `=dup`, `=sink`, and `=wasMoved`
- exception boundaries where `Defect` may escape instead of `CatchableError`

Skip style-only issues, unreachable theoretical bugs, and spec disagreements
without credible confidentiality, integrity, availability, or privilege impact.

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
| `LIKELY` | Complete static trace shows attacker-controlled input reaches a missing guard, but dynamic confirmation is not completed. |
| `LOW` | Reachability or impact depends on uncommon configuration, timing, deployment assumptions, or unclear caller behavior. |
| `FALSE_POSITIVE` | A guard, type constraint, catch boundary, limit, or unreachable path blocks the issue. |
| `NON_SECURITY` | The behavior is a bug or spec mismatch without credible security impact. |

Never mark a finding `CONFIRMED` from source reasoning alone.

## Score With Coarse Confidence

Do not multiply pseudo-probabilities.

| Score | Meaning |
|---:|---|
| 0.95 | Confirmed with reproducer or sanitizer/fuzzer artifact and root-cause trace. |
| 0.80 | Confirmed by deterministic integration test; exploitability constraints are understood. |
| 0.60 | Likely: complete static trace, clear attacker control, no dynamic confirmation yet. |
| 0.40 | Plausible: partial trace or deployment-dependent exploitability. |
| 0.20 | Weak: speculative, unclear reachability, or low impact. |
| 0.00 | False positive or non-security behavior. |

If two adjacent scores fit, choose the lower score and state the missing
evidence.

## Reduce False Positives

Before reporting, check:

- attacker control at the vulnerable point
- reachability under the project build flags and `when defined(...)` branches
- size limits, timeouts, auth checks, enum/range types, and parser guards
- parser consumed-length semantics and whether callers check full consumption
- whether the code catches the actual exception type or only `CatchableError`
- whether `-d:danger` changes overflow or assertion behavior
- async cancellation, reentrancy, and shared-state effects
- FFI pointer lifetimes, nullability, struct layout, calling convention, and string ownership
- ownership hook behavior for move-after-destroy, self-copy, zero-length allocation, and destroy-after-move

If a guard blocks the path, report `FALSE_POSITIVE` with the blocking line.

## Require Evidence

Every reported finding needs:

- title, classification, and confidence
- affected file and line
- attacker-controlled input or state
- static trace from entry point to failure
- expected vs actual behavior
- root cause
- exploitability and impact
- reproduction command or reason dynamic reproduction was not completed
- remediation direction

For `CONFIRMED`, also include exact input, commands, observed output, crash,
stack trace, sanitizer report, or saved artifact.

# Workflow

1. **Map the boundary.** Identify target files, entry points, untrusted inputs,
   sensitive operations, and existing guards. Output:
   `Entry | Input Control | Path | Sensitive Operation | Existing Guard`.
2. **Enumerate risk sites.** Use the search patterns above. Keep only sites
   reachable from the boundary.
3. **Generate bounded hypotheses.** Create at most two per risk site. Each must
   name exact input shape, attacker control, expected behavior, suspected actual
   behavior, and shortest code path.
4. **Static trace for 5-10 minutes.** Check guards, catches, limits, consumed
   lengths, and build-mode branches.
5. **Write a minimal reproducer for 10-20 minutes.** Prefer direct calls before
   integration tests. Use `doAssert`; do not rely on `assert`.
6. **Run relevant modes.** Start with:

   ```bash
   nim c -r repro.nim
   nim c --panics:on --mm:arc -r repro.nim
   nim c -d:release --lineTrace:on -r repro.nim
   nim c -d:danger --lineTrace:on -r repro.nim
   ```

   Skip irrelevant modes, but say why.
7. **Use sanitizers only for unsafe memory, FFI, or manual allocation.**

   ```bash
   nim c --cc:clang -g -d:noSignalHandler -d:useMalloc \
     --passC:"-fsanitize=address,undefined -fno-omit-frame-pointer" \
     --passL:"-fsanitize=address,undefined -fno-omit-frame-pointer" \
     -r repro.nim
   ```

8. **Use fuzzing or integration tests only when direct reproduction is
   insufficient.** Keep the harness narrow and save inputs, commands, and logs.
9. **Classify and report.** If confirmation exceeds the time box, downgrade to
   `LIKELY` or `LOW` and state the missing evidence.

# Common Mistakes

| Mistake | Why it is wrong |
|---|---|
| Marking a source-only claim `CONFIRMED` | Confirmation requires executable evidence. |
| Reporting a risky API call without a reachable attacker-controlled path | API presence is not a vulnerability. |
| Ignoring `Defect` vs `CatchableError` | `IndexDefect`, `OverflowDefect`, and `AssertionDefect` can escape ordinary recoverable-error handlers. |
| Using precise-looking probability math | It hides uncertainty and encourages over-claiming. |
| Spending too long on one hypothesis | Bounded confirmation keeps the audit moving and forces honest downgrades. |
| Treating `assert` as a reliable security check | `assert` is compiled out in `-d:danger`; use `doAssert` in tests. |

# References

No reference files yet.

# Changelog

- 2026-05-08: Imported into `skills_experiment`; added evidence-gated triage,
  coarse confidence scoring, bounded confirmation, and Nim-specific false
  positive checks.
