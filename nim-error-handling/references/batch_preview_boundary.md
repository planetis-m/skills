# Batch Failure Boundary

Records per-item processing failures at a batch boundary; if the recording path fails, that failure escapes.

```nim
import std/strutils

type
  ParseOutcome = object
    ok: bool
    value: float
    errorMsg: string

  BatchResult = object
    succeeded: int
    failed: int
    outcomes: seq[ParseOutcome]

proc appendLog(logPath: string; line: string) =
  let f = open(logPath, fmAppend)
  f.writeLine(line)
  f.close()

proc runBatch(inputs: seq[string]; logPath: string): BatchResult =
  for input in inputs:
    try:
      let value = parseFloat(input)
      result.outcomes.add ParseOutcome(ok: true, value: value)
      inc result.succeeded
    except ValueError:
      let msg = getCurrentExceptionMsg()
      appendLog(logPath, input & ": " & msg)
      result.outcomes.add ParseOutcome(ok: false, errorMsg: msg)
      inc result.failed
```

## Key points

- `parseFloat` stays straight-line; invalid input raises `ValueError` and lets it propagate.
- `runBatch` converts each processing failure into an ordered per-item outcome.
