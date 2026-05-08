---
name: nim-fuzzing
description: Set up and run libFuzzer-based fuzz targets for Nim code, including harness wiring, compilation flags, corpus management, structure-aware mutators, and crash triage. Use when adding fuzzing to a Nim project, building a fuzz harness for a parser/protocol/format handler, or reproducing and minimizing a fuzzer-found crash.
---

# Preamble

Use this skill to build, run, and triage libFuzzer targets for Nim code.
libFuzzer is an in-process, coverage-guided fuzzing engine from LLVM/Clang.
It works by repeatedly calling a user-defined `LLVMFuzzerTestOneInput` with
mutated byte buffers, measuring coverage, and retaining inputs that discover
new code paths.

The skill covers harness structure, compilation, corpus creation, custom
mutators for structured formats, standalone reproduction, and crash triage.
It does NOT cover writing the code under test — only wiring it to the fuzzer.

Worked examples live in `references/`.

# Rules

## Harness structure: the two required procs

Every Nim fuzz target needs exactly two exported procs with these signatures:

```nim
proc initialize(): cint {.exportc: "LLVMFuzzerInitialize".} =
  {.emit: "N_CDECL(void, NimMain)(void); NimMain();".}

proc testOneInput(data: ptr UncheckedArray[byte], len: int): cint {.
    exportc: "LLVMFuzzerTestOneInput", raises: [].} =
  result = 0
  # exercise code under test with data[0..<len]
```

`initialize` is called once at startup. It bootstraps Nim's runtime via
`NimMain()`. Without it the target will segfault before any inputs are tested.

`testOneInput` is called by libFuzzer with a raw byte buffer. It must return
0. Use `raises: []` — any uncaught exception will crash the fuzzer process,
which is treated as a finding.

## Minimum working example

```nim
proc fuzzMe(data: openarray[byte]): bool =
  result = data.len >= 3 and
    data[0].char == 'F' and
    data[1].char == 'U' and
    data[2].char == 'Z' and
    data[3].char == 'Z' # out-of-bounds: FUZZ is only 4 bytes

proc initialize(): cint {.exportc: "LLVMFuzzerInitialize".} =
  {.emit: "N_CDECL(void, NimMain)(void); NimMain();".}

proc testOneInput(data: ptr UncheckedArray[byte], len: int): cint {.
    exportc: "LLVMFuzzerTestOneInput", raises: [].} =
  result = 0
  discard fuzzMe(data.toOpenArray(0, len-1))
```

## Data extraction patterns

How to convert `ptr UncheckedArray[byte]` + `len` to Nim types:

| Target format          | Extraction code |
|------------------------|-----------------|
| raw byte buffer        | `data.toOpenArray(0, len-1)` |
| string                 | `var s = newString(len); copyMem(addr s[0], data, len)` |
| seq[T] via copyMem    | `let n = len div sizeof(T); var s = newSeq[T](n); copyMem(addr s[0], data, n * sizeof(T))` |
| interpret as C struct  | `if len < sizeof(MyType): return 0; let p = cast[ptr MyType](data)` |
| stream-based parsing   | `let str = newMemStream(data.toOpenArray(0, len-1))` (requires a MemStream impl) |

For the copyMem patterns, the fuzzer-provided buffer is a flat byte array.
Convert to typed Nim data after bounds-checking `len`.

## Error handling in the harness

Compile fuzz targets with `--panics:on`. This turns `Defect` subtypes
(`IndexDefect`, `OverflowDefect`, `AssertionDefect`, etc.) into non-catchable
panics that immediately crash the process — which libFuzzer interprets as a
finding. You don't need a manual `except Defect` block.

`testOneInput` must have `raises: []`. Catch only specific expected error
types (e.g., `except ValueError`) and let everything else crash. Never use
`except Exception` — it catches `Defect` even with panics off, masking real
bugs. Bare `except` is equivalent to `except CatchableError` and does not
catch `Defect` in Nim 2.3.1.

```nim
proc testOneInput(data: ptr UncheckedArray[byte], len: int): cint {.
    exportc: "LLVMFuzzerTestOneInput", raises: [].} =
  result = 0
  if len == 0: return
  var input = newString(len)
  copyMem(addr input[0], data, len)
  try:
    parseMyFormat(input)
  except ValueError:
    discard          # expected rejection
  # Defects crash the process — no catch needed with --panics:on
```

## Compilation

### Build config file (recommended)

Place a `fuzztarget.nims` next to the harness:

```nim
--cc: clang
--panics: on
--define: noSignalHandler
--define: useMalloc
--noMain: on
--passC: "-fsanitize=fuzzer,address,undefined"
--passL: "-fsanitize=fuzzer,address,undefined"
--debugger: native
```

| Flag                   | Purpose |
|------------------------|---------|
| `--cc: clang`          | libFuzzer requires Clang. |
| `--panics: on`         | Turns Defect into immediate crashes — no manual catch needed in harness. |
| `--noMain: on`         | libFuzzer provides its own `main`. |
| `--define: noSignalHandler` | Prevents Nim's signal handler from intercepting crashes before ASan. |
| `--define: useMalloc`  | Uses C malloc so ASan tracks all allocations. |
| `--passC:"-fsanitize=fuzzer,address,undefined"` | Enables libFuzzer + ASan + UBSan in compiler. |
| `--passL:"-fsanitize=fuzzer,address,undefined"` | Links the sanitizer runtimes. |
| `--debugger: native`   | Embeds DWARF debug info for source locations in reports. |

### Single-command compilation (no config file)

```bash
nim c --cc:clang --panics:on -d:noSignalHandler -d:useMalloc --noMain:on \
  --passC:"-fsanitize=fuzzer,address,undefined" \
  --passL:"-fsanitize=fuzzer,address,undefined" \
  -g my_fuzzer.nim
```

## Corpus management

libFuzzer needs a corpus directory. Start with at least one seed input:

```bash
mkdir corpus
echo "GET / HTTP/1.1" > corpus/seed_01
```

The fuzzer stores new coverage-discovering inputs into the corpus
automatically. When restarting, pass the corpus directory to retain progress:

```bash
./my_fuzzer corpus/
```

### Seed quality

Provide 1–5 small, valid inputs. Invalid seeds waste cycles. For protocol
fuzzers, seed with minimal valid examples. For binary formats, use small
well-formed files. Seeds should exercise the main code path, not degenerate
cases.

## Running the fuzzer

Basic run:

```bash
./my_fuzzer corpus/
```

Useful flags (passed as CLI args to the compiled binary, not to `nim c`):

| Flag              | Effect |
|-------------------|--------|
| `-fork=N`         | Run N parallel workers. Use 1 for debugging, CPU count for throughput. |
| `-ignore_crashes=1` | Don't stop on first crash; keep fuzzing for more findings. |
| `-max_len=N`      | Cap input size at N bytes. |
| `-runs=N`         | Execute exactly N runs then exit. Use for CI/regression. |
| `-close_fd_mask=1` | Close stdout; useful when running many workers. |
| `-max_total_time=N` | Run for N seconds then exit. |
| `-dict=DICT_FILE` | Use a dictionary of keywords/tokens to guide mutations. |

Example:

```bash
./my_fuzzer -fork=4 -ignore_crashes=1 -max_len=65536 corpus/
```

## Standalone mode: reproduce crashes without libFuzzer

Add `-d:fuzzSa` when compiling to build a standalone binary that replays
inputs from files instead of linking libFuzzer. This requires including the
`standalone.nim` helper (copy `libfuzzer/standalone.nim` from the libFuzzer
project).

In the harness:

```nim
when defined(fuzzSa):
  include standalone
```

Compile:

```bash
nim c -d:fuzzSa my_fuzzer.nim
```

Run against a crash input:

```bash
./my_fuzzer crash_input
```

The standalone binary reads each argument as a file path, feeds its contents
to `testOneInput`, and reports results. Use this to reproduce findings
without the full fuzzer engine.

## Structure-aware fuzzing with custom mutators

For structured formats (protocols, serialized types, typed data), raw byte
mutation is inefficient — most mutations produce invalid inputs rejected
early. Add `customMutator` and optionally `customCrossOver` to mutate at the
domain level.

### customMutator signature

```nim
proc customMutator(data: ptr UncheckedArray[byte], len, maxLen: int,
    seed: int64): int {.exportc: "LLVMFuzzerCustomMutator", raises: [].}
```

Called by libFuzzer to mutate `data` in-place. Must:
- Read the typed structure from `data[0..<len]`
- Apply a type-aware mutation (change/add/delete element, shuffle, flip bit)
- Write the result back into `data[0..<maxLen]`
- Return the new byte length (≤ `maxLen`)

Use the `seed` for deterministic randomness. On failure, return the original
`len`.

### customCrossOver signature

```nim
proc customCrossOver(data1: ptr UncheckedArray[byte], len1: int,
    data2: ptr UncheckedArray[byte], len2: int,
    res: ptr UncheckedArray[byte], maxResLen: int,
    seed: int64): int {.exportc: "LLVMFuzzerCustomCrossOver", raises: [].}
```

Combines two inputs into `res`. Same constraints as customMutator.

### When to add custom mutators

Add a custom mutator when:
- The format has a clear structural boundary (fields, chunks, typed elements)
- Raw byte mutation produces >90% invalid inputs
- Coverage stalls despite a good seed corpus

Start without one. Add only when the fuzzer fails to make progress.

See `references/structure_aware_fuzzing.md` for a worked example.

## Crash triage workflow

1. **Save the artifact.** libFuzzer writes crash inputs as files named
   `crash-<hash>`, `slow-unit-<hash>`, etc. Copy them to a permanent
   location.

2. **Reproduce with the standalone binary.** Compile with `-d:fuzzSa` and
   feed the crash input. Confirm the crash is deterministic.

3. **Minimize the input.** Run the fuzzer with `-minimize_crash=1`:

   ```bash
   ./my_fuzzer -minimize_crash=1 crash_input
   ```

   This produces a smaller, still-crashing input.

4. **Isolate with sanitizers.** Rebuild with only one sanitizer at a time
   to understand the bug type:

   ```bash
   # ASan only
   nim c --cc:clang -d:noSignalHandler -d:useMalloc --noMain:on \
     --passC:"-fsanitize=fuzzer,address" \
     --passL:"-fsanitize=fuzzer,address" -g my_fuzzer.nim

   # UBSan only
   nim c --cc:clang -d:noSignalHandler -d:useMalloc --noMain:on \
     --passC:"-fsanitize=fuzzer,undefined" \
     --passL:"-fsanitize=fuzzer,undefined" -g my_fuzzer.nim
   ```

5. **Write a minimal Nim reproducer.** Extract the failing operation into a
   standalone `.nim` file with a `doAssert`-based test. Keep the original
   crash input and sanitizer report as evidence.

6. **Classify findings** using the framework from the `nim-vuln-discovery`
   skill. A fuzzer finding with an artifact and sanitizer report is
   `CONFIRMED`.

## Coverage reporting

Build with Clang source-based coverage:

```bash
nim c --cc:clang \
  --passC:"-fprofile-instr-generate -fcoverage-mapping" \
  --passL:"-fprofile-instr-generate -fcoverage-mapping" \
  my_fuzzer.nim

LLVM_PROFILE_FILE="fuzz.profraw" ./my_fuzzer -runs=10000 corpus/
llvm-profdata merge -sparse fuzz.profraw -o fuzz.profdata
llvm-cov show ./my_fuzzer -instr-profile=fuzz.profdata --format=html \
  --output-dir=coverage_report
```

# Workflow

1. **Identify the fuzz target.** Pick a function or module that parses,
   deserializes, or processes untrusted byte input. It must be callable from
   a single entry point.

2. **Set up project files.** Copy `libfuzzer/fuzztarget.nim`,
   `libfuzzer/fuzztarget.nims`, and `libfuzzer/standalone.nim` into the
   project's test directory. Fill in `testOneInput` and `initialize`.

3. **Create a seed corpus.** Provide 1–5 minimal valid inputs in `corpus/`.

4. **Build and smoke-test.** Compile with the fuzzer config. Run with
   `-runs=1` to verify the harness starts and processes a seed.

5. **Start fuzzing.** Run with `-fork=N` for parallel workers. Let it run.
   Check `ls corpus/` periodically to see new coverage-discovering inputs.

6. **Inspect for slow units.** Files named `slow-unit-*` indicate inputs
   that take unusually long. Review whether the code has algorithmic
   complexity issues.

7. **Triage crashes.** For each crash artifact, follow the crash triage
   steps above: confirm, minimize, isolate sanitizer, write reproducer.

8. **Iterate.** If coverage stalls and the format is structured, add a
   custom mutator. If the harness rejects too many inputs, relax validation
   in the fuzz path.

# Common Mistakes

| Mistake | Why it is wrong |
|---------|-----------------|
| Omitting `initialize` / `NimMain()` | The Nim runtime is not bootstrapped. The target segfaults before any input is tested. |
| Forgetting `raises: []` on `testOneInput` | Exceptions propagate to C, producing confusing crash reports. With `--panics:on`, Defects crash cleanly, but CatchableErrors still need raises: []. |
| Using `assert` instead of `doAssert` in the code under test | `assert` is compiled out in `-d:danger`. The fuzzer won't find the bug. |
| Compiling with gcc instead of clang | libFuzzer is Clang-only. |
| Running ASan without `-d:useMalloc` | Nim's default allocator is not intercepted. ASan misses heap bugs. |
| Running ASan without `-d:noSignalHandler` | Nim's signal handler masks crashes before ASan reports. |
| Using `--passC` without `--passL` for sanitizers | The sanitizer runtime must be linked. Both flags are required. |
| Compiling without `--panics:on` | Without panics, you need manual `except Defect: quit(70)` blocks. Panics simplify the harness: any Defect automatically crashes the process. |
| Using invalid seeds | The fuzzer wastes cycles re-discovering valid structure before finding interesting mutations. |
| Writing a custom mutator prematurely | libFuzzer's built-in mutators handle many formats well. Add custom mutators only after coverage stalls. |
| Not bounding input size with `-max_len` | Unbounded inputs can cause memory exhaustion or slow runs. |
| Catching `except Exception` in the harness | `except Exception` catches `Defect` subclasses including `IndexDefect` and `OverflowDefect`, masking real bugs. Bare `except` (same as `except CatchableError`) does **not** catch `Defect`. Catch only specific expected error types like `ValueError`. Compile with `--panics:on` instead of manually catching Defect. |

# References

- `references/simple_byte_target.md` — Minimum working fuzz target for raw bytes
- `references/structure_aware_fuzzing.md` — Custom mutator and crossover for typed data
- `references/protocol_fuzzer.md` — Full HTTP request parser harness with error triage

# Changelog

- 2026-05-08: Created and verified.
