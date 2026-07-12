---
name: nim-testing
description: Write and run deterministic Nim tests, including isolated test files, expected-exception checks, multi-configuration builds, and sanitizer integration. Use when setting up a Nim test suite, testing failure behavior, running tests across debug/release/danger modes, or adding AddressSanitizer support.
---

# Nim Testing

Write deterministic Nim tests with direct assertions, isolated test files, multi-configuration runs, and optional AddressSanitizer checks.

## Rules

### Use `block`-based tests with `doAssert`

Import `std/assertions`. Use `block` scopes with `doAssert` and `doAssertRaises`:

```nim
import std/assertions

block add_basic:
  doAssert add(1, 2) == 3, "add should sum positive integers"

block greet_empty:
  doAssert greet("") == "hello "

block parse_bad_input:
  doAssertRaises ValueError:
    discard parseThing("")
```

`doAssert` raises `AssertionDefect` on failure. `doAssertRaises` passes only when the requested exception type is raised; otherwise the test exits non-zero.

### Write unambiguous assertions

Use ordinary call syntax and grouped negation inside `doAssert`:

```nim
proc foo(x: int): int = x
proc same(x, y: int): bool = x == y

doAssert foo(1) == 1, "foo should return its argument"
doAssert same(1, 1), "same values should match"
doAssert not (foo(1) < 0), "foo should not return a negative value"
doAssert 4 notin @[1, 2, 3]
```

Avoid command-call syntax in assertions. `doAssert foo 1 == 1` can bind the
comparison to `foo`, and `doAssert same 1, 1` can bind the comma to `doAssert`.

### Project layout

```
project/
  src/
    mylib.nim
  tests/
    config.nims        # shared compiler switches
    tester.nim         # central test runner (auto-discovers t*.nim)
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

echo "All test files completed."
```

Run from project root: `nim c -r tests/tester.nim`

New test files are auto-discovered — no runner edits needed.

### Shared Test Code

Keep test files self-contained when practical. If setup is repeated, extract domain helpers such as sample builders, temp-file setup, or fixture data.

## Workflow

1. **Set up layout.** Create `src/`, `tests/`, and `tests/config.nims`.
2. **Write test files.** Name files with `t` prefix. Use `block`, `doAssert`, and `doAssertRaises`.
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
- **Stack traces:** Release and danger show only the raising frame. Add `--lineTrace:on` to restore full traces with line numbers.
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
| Relying on `OverflowDefect` without `when defined(danger)` | Never raised in danger mode. |
| Running ASan without `-d:useMalloc` | Nim's default allocator is not intercepted by ASan. |
| Running ASan without `-d:noSignalHandler` | Nim's signal handler intercepts SIGSEGV before ASan reports. |
| Using only `--passC` without `--passL` for ASan | The sanitizer runtime must be linked. |
| Writing `doAssert foo 1 == 1` | Nim parses it like `doAssert foo(1 == 1)`. Use `doAssert foo(1) == 1`. |

## References

- `references/block_test_pattern.md` — Full worked example with project layout, test files, and runner
- `references/ci_github_actions.md` — GitHub Actions CI workflow for Linux, macOS, and Windows
