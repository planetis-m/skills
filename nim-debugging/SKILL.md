---
name: nim-debugging
description: Debug Nim programs using echo-based inspection, stack traces, compiler expansion flags, and runtime memory sanitizers. Use when diagnosing runtime crashes, unexpected behavior, memory errors, macro output, or ARC/ownership issues in Nim code.
---

# Nim Debugging

Practical techniques for debugging Nim programs: echo-based inspection, stack traces, compiler expansion flags, memory sanitizers, and ARC/ownership debugging. Verified on Nim 2.3.1 with gcc 15 on Linux.

Extended examples live in `references/`.

## Rules

### Build modes and stack traces

| Build mode            | Opt level | Stack traces with line numbers | `writeStackTrace()` output |
|-----------------------|-----------|-------------------------------|---------------------------|
| default / `-d:debug`  | none      | Full: file path + line number | Full with file paths and line numbers |
| `-d:release`          | speed     | Only the raising frame        | `No stack traceback available` |
| `-d:danger`           | speed     | Only the raising frame        | `No stack traceback available` |

To restore full stack traces in release or danger mode:

```
--lineTrace:on
```

`--lineTrace:on` implies `--stackTrace:on`. Both names can be used together for clarity.

`--excessiveStackTrace:on` (the default) shows full file paths. `--excessiveStackTrace:off` shows only filenames.

### Echo-based debugging

Use `echo` to inspect values. For types without a `$` operator, use `repr`:

```nim
echo "x = ", x
echo "r = ", repr(r)      # works on any type
```

`repr` output examples: `MyRef(x: 42, s: "hello")` for ref objects, `@[1, 2, 3]` for sequences, `"world"` for strings, hex address for raw pointers.

Inside `{.noSideEffect.}` procs, use `debugEcho` instead of `echo` — it compiles where `echo` would be rejected.

### Buffering and `stdout.flushFile`

`echo` flushes automatically. `stdout.write` does not. Short output written with `stdout.write` may stay buffered and be lost if the program crashes before the buffer drains.

When using `stdout.write` for debug output, call `stdout.flushFile()` after each write to guarantee the output appears before any crash.

### `compiles` as a diagnostic

`compiles(expr)` returns `true` if the expression type-checks and compiles, `false` otherwise. Use it to narrow down generic instantiation failures, macro output issues, or type mismatches without recompiling:

```nim
echo compiles(myGenericProc(int))  # true or false
```

It works at compile time and at runtime (as a `const bool`).

### `writeStackTrace()`

Call `writeStackTrace()` to print the current call stack. Works in debug mode. Returns `No stack traceback available` in release and danger unless compiled with `--lineTrace:on`.

### Macro debugging: `--expandMacro`

```
nim c --expandMacro:<macro_name> <file.nim>
```

The compiler prints the expanded AST as a hint tagged `[ExpandMacro]`. Multiple `--expandMacro` flags can be combined. Works with any build mode or memory manager.

### ARC/ownership debugging: `--expandArc`

```
nim c --expandArc:<proc_name> <file.nim>
```

Shows injected `=copy`, `=destroy`, `=sink`, and `move` calls. The target proc must be reachable from the program entry point. Works with all three memory managers (`--mm:orc`, `--mm:arc`, `--mm:atomicArc`). Output is the same across all three for simple patterns; differences appear in cyclic-reference handling (ORC only).

See `references/arc_optimization.md` for a worked example.

### Memory management modes

| Flag              | Behavior                                      |
|-------------------|-----------------------------------------------|
| `--mm:orc`        | Default. Cycle-collecting reference counting. |
| `--mm:arc`        | Reference counting without cycle collection.  |
| `--mm:atomicArc`  | Same as `arc` with atomic reference counting. |

Test under the same `--mm:` mode your project uses.

### Debug info for native debuggers

`-g` and `--debugger:native` are equivalent. Both expand to `--debuginfo --linedir:on` and embed DWARF debug info in the binary.

Do not use `gdb`. Use AddressSanitizer or Valgrind instead.

### Runtime memory diagnostics

Use these when working with unsafe constructs: `addr`, `ptr T`, `cstring`, `cstringArray`, manual `alloc`/`dealloc`, or C FFI.

#### AddressSanitizer (primary)

Detects heap-buffer-overflow, use-after-free, double-free, stack-buffer-overflow, and memory leaks.

**Linux/macOS (gcc or clang):**

```
nim c \
  --passC:"-fsanitize=address -fno-omit-frame-pointer" \
  --passL:"-fsanitize=address -fno-omit-frame-pointer" \
  -g \
  -d:noSignalHandler \
  -d:useMalloc \
  <file.nim>
```

- `--passC` / `--passL`: Both required. Passes sanitizer flags to the C compiler and linker.
- `-g`: Embeds debug info so ASan reports show Nim source locations.
- `-d:noSignalHandler`: Prevents Nim's signal handler from intercepting the crash.
- `-d:useMalloc`: Makes Nim use C's `malloc` so ASan can track every allocation. Works with `--mm:arc` and `--mm:orc`.

On error, ASan prints a report with Nim file and line:

```
==14455==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x...
READ of size 8 at 0x... thread T0
    #0 ... in test_asan_oom::main /tmp/.../test_asan_oom.nim:8
```

**clang:** Add `--cc:clang`. Requires `llvm-symbolizer` in `$PATH` for Nim source locations in the report. gcc resolves symbols natively.

**Windows (MSVC):**

```
nim c --cc:vcc --passC:"/fsanitize=address" <file.nim>
```

#### Valgrind (secondary)

Use when ASan is unavailable. Does not require special compilation flags.

```
nim c -g -o:<binary> <file.nim>
valgrind --leak-check=full --error-exitcode=1 ./<binary>
```

Slower than ASan. Does not require `-d:useMalloc`.

## Workflow

1. **Reproduce the issue.** Build in default mode (debug). Confirm the error is reproducible.
2. **Read the stack trace.** Default builds show full traces. If missing in release/danger, add `--lineTrace:on`.
3. **Add echo inspection.** Insert `echo` or `debugEcho` calls. Use `repr` for complex types.
4. **If the issue is in a macro**, run `nim c --expandMacro:<name>` and inspect the expanded AST.
5. **If the issue involves ownership or copies**, run `nim c --expandArc:<proc>` under the project's `--mm:` mode.
6. **If the issue involves unsafe memory** (`ptr`, `addr`, `cstring`, manual alloc), rebuild with AddressSanitizer. If ASan is unavailable, use Valgrind.
7. **If the issue only appears in release/danger**, rebuild with `--lineTrace:on` plus the release/danger flag to get traces.
8. **Verify the fix.** Remove debug prints. Run under ASan if memory was involved.

## Common Mistakes

| Mistake | Why it is wrong |
|---------|-----------------|
| Using `-d:release` and expecting full stack traces | Release disables line tracing. Add `--lineTrace:on`. |
| Running ASan without `-d:useMalloc` | Nim's default allocator may not be fully intercepted by ASan. |
| Running ASan without `-d:noSignalHandler` | Nim's signal handler intercepts SIGSEGV before ASan can report. |
| Using only `--passC` without `--passL` for ASan | The sanitizer runtime must be linked. Both are required. |
| Using `echo` inside `{.noSideEffect.}` procs | Won't compile. Use `debugEcho`. |
| Using clang ASan without `llvm-symbolizer` | ASan detects the error but shows raw hex addresses. Install `llvm-symbolizer` or use gcc. |
| Using `gdb` | Name mangling makes variable inspection unreliable. Use ASan or echo-based debugging. |

## References

- `references/arc_optimization.md` — Worked example: identifying and fixing an unnecessary copy using `--expandArc`

## Changelog

- 2026-04-20: Added `stdout.flushFile` buffering, `compiles` diagnostic. Created on Nim 2.3.1 / gcc 15 / Linux.
