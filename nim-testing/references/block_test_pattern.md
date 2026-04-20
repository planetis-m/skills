Full worked example showing project layout, block-based tests, a helper module, and the auto-discovering runner.

## Project layout

```
project/
  src/
    mylib.nim
  tests/
    config.nims
    tester.nim
    thelper.nim
    tbasic.nim
    tedge.nim
```

## `src/mylib.nim`

```nim
proc add*(a, b: int): int = a + b
proc greet*(name: string): string = "hello " & name
```

## `tests/config.nims`

```nim
switch("path", "$projectdir/../src")
```

## `tests/thelper.nim`

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

## `tests/tbasic.nim`

```nim
import mylib
import thelper

block add_basic:
  check add(1, 2) == 3, "add(1, 2) should be 3"
  check add(-1, 1) == 0, "add(-1, 1) should be 0"
  check add(0, 0) == 0, "add(0, 0) should be 0"

block greet_basic:
  check greet("world") == "hello world", "greet world"
  check greet("") == "hello ", "greet empty"

block add_overflow:
  when defined(danger):
    check true, "overflow checks skipped in danger mode"
  else:
    let big = high(int) - 1
    var raised = false
    try:
      discard add(big, 2)
    except OverflowDefect:
      raised = true
    check raised, "overflow raises OverflowDefect"

summary()
```

## `tests/tedge.nim`

```nim
import mylib
import thelper

block greet_with_spaces:
  check greet("  ") == "hello   ", "greet spaces"

block add_negative:
  check add(-5, -3) == -8, "negative addition"

summary()
```

## `tests/tester.nim`

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

echo ""
echo "All test files completed."
```

## Run commands

```bash
# Default (debug)
nim c -r tests/tester.nim

# Release
nim c -d:release -r tests/tester.nim

# Danger
nim c -d:danger -r tests/tester.nim

# AddressSanitizer
nim c \
  --passC:"-fsanitize=address -fno-omit-frame-pointer" \
  --passL:"-fsanitize=address -fno-omit-frame-pointer" \
  -g -d:noSignalHandler -d:useMalloc \
  -r tests/tester.nim
```

Key points:

- Each test file is self-contained with its own `block` scopes and calls `summary()` at the end.
- The runner auto-discovers all `tests/t*.nim` files. Adding a new test file requires no runner changes — just create `tests/t<name>.nim`.
- Each test file compiles and runs as a separate process. A crash in one file does not prevent others from running.
- `config.nims` uses `$projectdir` to resolve the path relative to the test file's directory.
