# Parameter And Result Shapes

Use plain defaults for simple optional inputs.
Group related knobs in one named object when a proc starts collecting too many parameters.
Use a named object for semantic returned data.

## Example

```nim
type
  WalkOptions = object
    relative*: bool
    skipHidden*: bool
    extension*: string
    maxDepth*: int

  SearchSummary = object
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
- Use sentinel defaults like `""` when they already fit the domain.
- Use a named object when the returned value is semantic domain data.
- Keep tuples for local glue, iterator yields, and small helper-style returns.
