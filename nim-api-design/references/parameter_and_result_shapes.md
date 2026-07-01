# Parameter And Result Shapes

Use direct defaults for simple options and named objects for grouped options or semantic results.

```nim
type
  WalkOptions* = object
    relative*: bool
    skipHidden*: bool
    extension*: string
    maxDepth: int

  SearchSummary* = object
    root*: string
    matchedPaths*: seq[string]
    skippedCount*: int

proc toWalkOptions*(extension = ".nim", relative = false, skipHidden = false,
    maxDepth: Natural = 0): WalkOptions =
  WalkOptions(
    relative: relative,
    skipHidden: skipHidden,
    extension: extension,
    maxDepth: maxDepth
  )

proc findFiles*(root: string; options = toWalkOptions()): SearchSummary {.raises: [ValueError].} =
  if root.len == 0:
    raise newException(ValueError, "root is empty")

  result = SearchSummary(
    root: root,
    matchedPaths: @["src/app.nim", "tests/app_test.nim"],
    skippedCount: 0
  )
```

Instead of:

```nim
proc findFiles*(root: string, relative = false, skipHidden = false, extension = ".nim",
    maxDepth: Natural = 0): tuple[root: string, matchedPaths: seq[string],
    skippedCount: int] =
  discard
```

## Key points

- Keep one or two simple optional inputs as plain parameters with plain defaults.
- Introduce an options object when a proc starts collecting related knobs.
- Use range types for constrained public parameters and base types for stored fields.
- Use a sentinel default only when that value has one unambiguous domain meaning.
- Use a named object for semantic results; keep tuples for local glue and iterator yields.
- Range checks run in debug and release builds, but not in danger mode or when disabled.
