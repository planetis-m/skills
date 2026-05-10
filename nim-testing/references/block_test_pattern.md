Full worked example showing project layout, block-based tests, direct assertions, and the auto-discovering runner.

## Project layout

```
project/
  src/
    mylib.nim
  tests/
    config.nims
    tester.nim
    tbasic.nim
    tedge.nim
```

## `src/mylib.nim`

```nim
proc add*(a, b: int): int = a + b
proc greet*(name: string): string = "hello " & name

proc requireName*(name: string): string =
  if name.len == 0:
    raise newException(ValueError, "name is empty")
  greet(name)
```

## `tests/config.nims`

```nim
switch("path", "$projectdir/../src")
```

## `tests/tbasic.nim`

```nim
import std/assertions

import mylib

block add_basic:
  doAssert add(1, 2) == 3, "add should sum positive integers"
  doAssert add(-1, 1) == 0, "add should handle signs"
  doAssert add(0, 0) == 0, "add should handle zero"

block greet_basic:
  doAssert greet("world") == "hello world"
  doAssert greet("") == "hello "

block require_name:
  doAssert requireName("world") == "hello world"
  doAssertRaises ValueError:
    discard requireName("")
```

## `tests/tedge.nim`

```nim
import std/assertions

import mylib

block greet_with_spaces:
  doAssert greet("  ") == "hello   "

block add_negative:
  doAssert add(-5, -3) == -8
```

## `tests/tester.nim`

```nim
import std/os

proc fatal(msg: string) = quit "FAILURE " & msg

proc exec(cmd: string) =
  echo "Running: ", cmd
  if execShellCmd(cmd) != 0: fatal cmd

let testDir = getCurrentDir() / "tests"
for f in walkFiles(testDir / "t*.nim"):
  let name = f.extractFilename
  if name == "tester.nim":
    discard
  else:
    exec "nim c -r " & quoteShell(testDir / name)

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

- Each test file is self-contained and uses `block` scopes with `doAssert` / `doAssertRaises`.
- The runner auto-discovers all `tests/t*.nim` files. Adding a new test file requires no runner changes — just create `tests/t<name>.nim`.
- Each test file compiles and runs as a separate process. A crash in one file does not prevent others from running.
- `config.nims` uses `$projectdir` to resolve the path relative to the test file's directory.
