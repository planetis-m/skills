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
    paths*: seq[string]
    skipped*: int

proc `==`*(a, b: WorkspaceId): bool {.borrow.}
proc `$`*(id: WorkspaceId): string {.borrow.}

proc initScanOptions*(extension = ".nim"; includeHidden = false;
    maxDepth: Natural = 0): ScanOptions =
  result = ScanOptions(
    extension: extension,
    includeHidden: includeHidden,
    maxDepth: maxDepth
  )

proc scan*(ws: WorkspaceId;
    opts = initScanOptions()): ScanSummary =
  if $ws == "":
    raise newException(ValueError, "workspace is empty")

  result = ScanSummary(
    workspace: ws,
    paths: @["src/app.nim", "tests/app_test.nim"]
  )
  if opts.includeHidden:
    result.paths.add ".config/plugin.nim"
```

## Key points

- `WorkspaceId` prevents accidental mixing with arbitrary strings.
- Define or borrow only the base comparison operators you need; Nim derives
  `!=`, `>`, and `>=`.
- Related scan knobs form one options object with a simple default path.
- `Natural` constrains the public parameter while storage remains `int`.
- `ScanSummary` gives the public result stable names and room to evolve.
