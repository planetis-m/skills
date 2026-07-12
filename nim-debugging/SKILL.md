---
name: nim-debugging
description: Debug Nim compile failures, crashes, wrong results, macro expansion, ownership behavior, and unsafe-memory defects using focused reproduction, stack traces, inspection, compiler expansion, and sanitizers. Use when diagnosing runtime failures, release-only behavior, generic or macro issues, unexpected copies, pointer bugs, or memory leaks.
---

# Nim Debugging

Debug by reducing uncertainty: preserve the failure, state one hypothesis, and
collect the smallest piece of evidence that can reject it. Find the first
violated invariant rather than stopping at the final crash.

Project configuration can override compiler defaults. Complete examples live
under `references/`.

# Rules

## Preserve the failure

- Record the exact input, command, working directory, backend, memory manager,
  thread setting, build mode, and relevant environment.
- Make the failure deterministic before changing code. If it is intermittent,
  preserve a seed, event order, or failing fixture.
- Change one diagnostic dimension at a time. A debug build that no longer
  fails is a comparison point, not a reproduction.
- Turn each confirmed defect into a regression test before removing
  instrumentation.

## Choose evidence by failure class

| Failure | First evidence |
| --- | --- |
| Compile-time type or generic question | Normal compiler diagnostic; use `compiles` only for a yes/no probe |
| Unhandled exception or defect | Default stack trace, or `--lineTrace:on` in the failing optimized mode |
| Wrong runtime value | `echo`, `debugEcho`, or `repr` at invariant boundaries |
| Buffered output lost at a crash | `stdout.write` followed by `stdout.flushFile()` |
| Macro-generated code | `--expandMacro:<name>` |
| Unexpected copy, move, or destruction | `--expandArc:<proc>` under the project memory manager |
| Pointer, manual allocation, or FFI memory error | AddressSanitizer with the complete required recipe |
| Independent leak or invalid-access check | Valgrind |

## Stack traces and build modes

Default build behavior:

| Mode | Unhandled exception trace | `writeStackTrace()` |
| --- | --- | --- |
| default or `-d:debug` | full paths and line numbers | full trace |
| `-d:release` | raising frame only | no traceback available |
| `-d:danger` | raising frame only | no traceback available |

- Add `--lineTrace:on` to the failing release or danger command to restore the
  call chain and line numbers. It implies `--stackTrace:on`.
- Use `--excessiveStackTrace:off` when filenames are sufficient; the default
  `on` form includes full paths.
- Call `writeStackTrace()` when the current path matters before an exception
  exists.
- Read the trace from the failure backward, then inspect values along that path
  until the first invalid state is found.

## Runtime inspection

- Use `echo` for ordinary values and `repr` when a type lacks useful `$`
  formatting.
- Use `debugEcho` inside `{.noSideEffect.}` code; ordinary `echo` is rejected
  there.
- `echo` flushes automatically. Flush `stdout.write` explicitly when a crash
  could occur before the buffer drains.
- Label diagnostic values with the phase and invariant being checked. Avoid
  dumping large structures when one length, index, tag, or identity answers
  the hypothesis.
- `compiles(expr)` is a compile-time boolean probe. If it returns `false`,
  compile the candidate normally to obtain the actual diagnostic.

## Compiler-generated code

- Run `nim c --expandMacro:<name> file.nim` to inspect a macro's expanded AST.
  The compiler emits an `[ExpandMacro]` hint.
- Run `nim c --expandArc:<proc> file.nim` to inspect injected copy, sink, move,
  and destroy operations.
- Keep an `--expandArc` target reachable from the entry point and use the
  target project's `--mm:` mode.
- Treat expansion output as evidence about generated operations, not as a
  reason to optimize by itself. `move` is destructive and requires deliberate
  last use plus behavior tests.
- Nim defaults to ORC. Read the compiler build hint because project
  configuration may select ARC or atomic ARC.

## AddressSanitizer

Use ASan for `ptr`, `addr`, `cstring`, `cstringArray`, manual allocation, and
C-FFI memory faults. The required Linux/GCC recipe is:

```bash
nim c \
  --passC:"-fsanitize=address -fno-omit-frame-pointer" \
  --passL:"-fsanitize=address -fno-omit-frame-pointer" \
  -g \
  -d:useMalloc \
  -d:noSignalHandler \
  file.nim
```

- Pass sanitizer flags to both compilation and linking.
- `-d:useMalloc` is required so ASan observes memory obtained through Nim's
  allocator.
- `-d:noSignalHandler` is required so ASan, rather than Nim's signal handler,
  reports signal faults.
- `-g` gives symbolized Nim locations with GCC. Add `--cc:clang` for Clang and
  ensure `llvm-symbolizer` is in `PATH`.
- Preserve the project's memory manager and failing input.
- Read both the invalid-access stack and the allocation/free stack before
  editing code.

See `references/memory_sanitizers.md` for a complete runnable example. Platform
recipes not verified in this repository are intentionally omitted.

## Valgrind

Use Valgrind as an independent native-memory check:

```bash
nim c -g -o:program file.nim
valgrind --leak-check=full --error-exitcode=1 ./program
```

It requires no sanitizer instrumentation and is slower than ASan. A non-zero
exit distinguishes detected errors in automated checks.

## Debug symbols and native debuggers

- `-g` and `--debugger:native` enable native debug information and line directives.
- This project does not use GDB: Nim name mangling and generated C make
  variable inspection slower and less reliable than stack traces, focused
  inspection, ASan, Valgrind, and compiler expansion.

# Workflow

1. Reproduce the failure with an exact command and fixed input.
2. Minimize unrelated setup while keeping the same failure and configuration.
3. State one falsifiable hypothesis and the invariant it predicts.
4. Select the narrowest evidence source from the failure-class table.
5. Follow the failing path backward and locate the first invalid state.
6. Fix the invariant at its owner instead of suppressing the final symptom.
7. Re-run the original reproduction and relevant sanitizer or expansion check.
8. Add a regression test, then remove temporary prints and scratch artifacts.

# Common Mistakes

| Mistake | Why it is wrong |
| --- | --- |
| Changing input, build mode, and code together | The result cannot identify which change affected the failure |
| Reading only the final crashing line | Corruption or invalid state commonly begins earlier |
| Expecting full traces from release or danger defaults | Add `--lineTrace:on` to the failing optimized command |
| Using `compiles` as a replacement for compiler diagnostics | It answers only yes or no and suppresses the candidate diagnostic |
| Printing with `stdout.write` immediately before a crash without flushing | Buffered evidence can be lost |
| Running ASan without `-d:useMalloc` | Nim allocator overflows can remain invisible to ASan |
| Running ASan without `-d:noSignalHandler` | Nim can intercept signal faults before ASan reports them |
| Passing ASan flags only to C compilation | The sanitizer runtime must also be linked |
| Using Clang ASan without `llvm-symbolizer` | Reports can contain raw addresses instead of Nim locations |
| Adding `move` merely because `--expandArc` shows a copy | `move` changes ownership semantics and must be safe at last use |
| Using GDB for routine Nim debugging | The project uses faster Nim-aware evidence sources instead |

# References

- `references/stack_trace_diagnosis.md` — trace a failure to the first invalid value
- `references/memory_sanitizers.md` — complete ASan and Valgrind commands
- `references/arc_optimization.md` — interpret ownership expansion and apply `move` safely
