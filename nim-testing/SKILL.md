---
name: nim-testing
description: Write and run Nim tests using block-based assertions, a central test runner, multi-configuration builds, and sanitizer integration. Use when setting up a Nim test suite, writing isolated test cases, running tests across debug/release/danger modes, or adding AddressSanitizer support.
---

# Nim Testing

Write and run isolated, deterministic Nim tests using `block`-based assertions. Covers project layout, an auto-discovering test runner, multi-configuration builds, and AddressSanitizer. Verified on Nim 2.3.1 with gcc 15 on Linux.

Extended examples and CI workflows live in `references/`.

## Rules

### Use `block`-based tests with `doAssert`

Prefer `block` + `doAssert` over `std/unittest`:

```nim
block add_basic:
  doAssert add(1, 2) == 3

block greet_empty:
  doAssert greet("") == "hello "
```

`doAssert` raises `AssertionDefect` on failure. The process exits with a non-zero code.

### `doAssert` vs `assert`

`doAssert` raises `AssertionDefect` in **all** build modes. Plain `assert` is compiled out in `-d:danger` — silently skipped. Use `doAssert` in tests.

### `Defect` exceptions are not caught by bare `except:`

`AssertionDefect` inherits from `Defect`, not `CatchableError`. Bare `except:` and `except CatchableError` do **not** catch it. Use the specific type:

```nim
block catch_overflow:
  var raised = false
  try:
    discard high(int) - 1 + 2
  except OverflowDefect:
    raised = true
  doAssert raised
```

This applies to all `Defect` subclasses: `AssertionDefect`, `OverflowDefect`, `FieldDefect`, `IndexDefect`, etc.

### Use `when defined(danger)` for mode-dependent tests

`-d:danger` disables overflow checks:

```nim
block add_overflow:
  when defined(danger):
    doAssert true
  else:
    var raised = false
    try:
      discard add(high(int) - 1, 2)
    except OverflowDefect:
      raised = true
    doAssert raised
```

### Project layout

```
project/
  src/
    mylib.nim
  tests/
    config.nims        # shared compiler switches
    tester.nim         # central test runner (auto-discovers t*.nim)
    thelper.nim        # shared helpers (optional)
    tbasic.nim
    tedge.nim
    terrors.nim
```

Test files use `t` prefix: `tbasic.nim`, `tedge.nim`, `terrors.nim`, `tintegration.nim`.

### `tests/config.nims`

```nim
switch("path", "$projectdir/../src")
```

The compiler loads this config automatically when compiling files in `tests/`.

### `tests/tester.nim`

```nim
import std/os

proc exec(cmd: string) =
  echo "Running: " & cmd
  if execShellCmd(cmd) != 0:
    quit "FAILURE: " & cmd, 1

let testDir = getCurrentDir() / "tests"
for f in walkFiles(testDir / "t*.nim"):
  let name = f.extractFilename
  if name == "tester.nim" or name == "thelper.nim":
    continue
  exec "nim c -r " & testDir / name

echo "All test files completed."
```

Run from project root: `nim c -r tests/tester.nim`

New test files are auto-discovered — no runner edits needed.

### Test helper module (optional)

For larger suites, extract into `tests/thelper.nim`:

```nim
var failures* = 0
var passed* = 0

proc check*(condition: bool; msg: string) =
  if condition:
    passed += 1
  else:
    failures += 1
    echo "  FAIL: " & msg

proc summary*() =
  echo "Passed: " & $passed & "  Failed: " & $failures
  if failures > 0:
    quit "TESTS FAILED", 1
  else:
    echo "ALL TESTS PASSED"
```

Each test file imports `thelper` and calls `summary()` at the end.

## Workflow

1. **Set up layout.** Create `src/`, `tests/`, and `tests/config.nims`.
2. **Write test files.** Use `block` + `doAssert`, name with `t` prefix.
3. **Create the runner.** Add `tests/tester.nim` with the auto-discover pattern.
4. **Run all configurations:**

   ```
   nim c -r tests/tester.nim
   nim c -d:release -r tests/tester.nim
   nim c -d:danger -r tests/tester.nim
   ```

5. **Run with ASan** if the project uses unsafe constructs. See "AddressSanitizer" below.
6. **Set up CI.** See `references/ci_github_actions.md`.

## Multi-configuration testing

| Mode                  | Overflow checks | Stack traces (file:line) |
|-----------------------|-----------------|--------------------------|
| default / `-d:debug`  | Yes             | Full                     |
| `-d:release`          | Yes             | Raising frame only       |
| `-d:danger`           | No              | Raising frame only       |

- **Overflow checks:** Disabled in danger. Use `when defined(danger)` guards.
- **Stack traces:** Release and danger show only the raising frame. Add `--lineTrace:on` to restore full traces.
- **`assert`:** Compiled out in danger. Use `doAssert`.

## AddressSanitizer

```
nim c \
  --passC:"-fsanitize=address -fno-omit-frame-pointer" \
  --passL:"-fsanitize=address -fno-omit-frame-pointer" \
  -g -d:noSignalHandler -d:useMalloc \
  -r tests/tester.nim
```

- `--passC` / `--passL`: Both required.
- `-g`: Embeds debug info for Nim source locations in reports.
- `-d:noSignalHandler`: Lets ASan report directly instead of Nim's signal handler.
- `-d:useMalloc`: Uses C's `malloc` so ASan tracks every allocation.

**Windows (MSVC):** `nim c --cc:vcc --passC:"/fsanitize=address" -r tests/tester.nim`

### Sanitizer config in `tests/config.nims`

```nim
switch("path", "$projectdir/../src")

when defined(addressSanitizer):
  switch("debugger", "native")
  switch("define", "noSignalHandler")
  switch("define", "useMalloc")
  when defined(windows):
    switch("passC", "/fsanitize=address")
  else:
    switch("passC", "-fsanitize=address -fno-omit-frame-pointer")
    switch("passL", "-fsanitize=address -fno-omit-frame-pointer")
```

Then: `nim c -d:addressSanitizer -r tests/tester.nim`

## Common Mistakes

| Mistake | Why it is wrong |
|---------|-----------------|
| Using `assert` instead of `doAssert` | `assert` is compiled out in danger. Use `doAssert`. |
| Using bare `except:` to catch `doAssert` failures | `AssertionDefect` is a `Defect`. Bare `except:` does not catch it. Use `except AssertionDefect` or `except Defect`. |
| Relying on `OverflowDefect` without `when defined(danger)` | Never raised in danger mode. |
| Running ASan without `-d:useMalloc` | Nim's default allocator may not be fully intercepted. |
| Running ASan without `-d:noSignalHandler` | Nim's signal handler intercepts SIGSEGV before ASan reports. |
| Using only `--passC` without `--passL` for ASan | The sanitizer runtime must be linked. |

## References

- `references/block_test_pattern.md` — Full worked example with project layout, test files, and runner
- `references/ci_github_actions.md` — GitHub Actions CI workflow for Linux, macOS, and Windows

## Changelog

- 2026-04-20: Created and verified on Nim 2.3.1 / gcc 15 / Linux.
