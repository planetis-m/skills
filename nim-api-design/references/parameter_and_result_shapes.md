Use distinct domain identities, an options object for related knobs, range
types at the callable boundary, and a named semantic result.

```nim
type
  WorkspaceId* = distinct string

  ScanOptions* = object
    extension*: string
    includeHidden*: bool
    maxDepth: int

  ScanSummary* = object
    workspace*: WorkspaceId
    matchedPaths*: seq[string]
    skippedCount*: int

proc `==`*(a, b: WorkspaceId): bool {.borrow.}
proc `$`*(id: WorkspaceId): string {.borrow.}

proc initScanOptions*(extension = ".nim"; includeHidden = false;
    maxDepth: Natural = 0): ScanOptions =
  ScanOptions(
    extension: extension,
    includeHidden: includeHidden,
    maxDepth: maxDepth
  )

proc scan*(workspace: WorkspaceId;
    options = initScanOptions()): ScanSummary =
  if $workspace == "":
    raise newException(ValueError, "workspace is empty")

  result = ScanSummary(
    workspace: workspace,
    matchedPaths: @["src/app.nim", "tests/app_test.nim"]
  )
  if options.includeHidden:
    result.matchedPaths.add ".config/plugin.nim"

let workspace = WorkspaceId("compiler")
let normal = scan(workspace)
doAssert normal.workspace == workspace
doAssert normal.matchedPaths.len == 2

let hidden = scan(workspace,
  initScanOptions(includeHidden = true, maxDepth = 3))
doAssert hidden.matchedPaths.len == 3
```

## Key points

- `WorkspaceId` prevents accidental mixing with arbitrary strings.
- Related scan knobs form one options object with a simple default path.
- `Natural` constrains the public parameter while storage remains `int`.
- `ScanSummary` gives the public result stable names and room to evolve.
