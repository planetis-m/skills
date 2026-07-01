Use a stack trace to identify the failing path, then instrument boundaries to
find the first invalid value rather than only the final crash.

```nim
import std/[os, parseutils, syncio]

proc parseCount(text: string): int =
  if parseInt(text, result) != text.len:
    raise newException(ValueError, "count is not an integer")

proc reserveSlots(count: int): seq[int] =
  if count < 0:
    raise newException(ValueError, "count must be non-negative")
  result = newSeq[int](count)

proc buildBatch(text: string): int =
  let count = parseCount(text)
  stdout.write "parsed count=", count, "\n"
  stdout.flushFile()
  result = reserveSlots(count).len

let input = if paramCount() == 1: paramStr(1) else: "3"
echo "slots=", buildBatch(input)
```

Start with the default build:

```bash
nim c -r example.nim -- -1
```

If the failure occurs only in an optimized build, preserve that configuration
and restore tracing:

```bash
nim c -r -d:release --lineTrace:on example.nim -- -1
```

The exception is raised in `reserveSlots`, but the flushed boundary value
shows that the state first became invalid when `parseCount` returned `-1`.
That distinction determines whether the fix belongs in parsing, validation, or
the caller contract.

## Key points

- Preserve the failing input and relevant build configuration.
- Read the call path, then inspect values at boundaries along that path.
- Locate the first violated invariant, not merely the last failing operation.
- `echo` flushes automatically. Pair `stdout.write` with `flushFile` when a
  crash could occur before buffered output is written.
- Remove temporary instrumentation after the regression test passes.
