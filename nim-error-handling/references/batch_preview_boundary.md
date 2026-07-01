# Batch Failure Boundary

This example records processing failures per item but lets audit failure abort the batch.

```nim
type
  PreviewItem = object
    path: string
    success: bool
    previewId: string
    errorMsg: string

  BatchSummary = object
    okCount: int
    failCount: int
    items: seq[PreviewItem]

proc fakeReadPages(path: string): seq[string] =
  if path.len == 0:
    raise newException(IOError, "path is empty")
  case path
  of "missing":
    raise newException(IOError, "document missing")
  of "blank":
    result = @[""]
  else:
    result = @[path & "-page-1", path & "-page-2"]

proc fakeUpload(payload: seq[byte]): string =
  if payload.len == 0:
    raise newException(OSError, "upload payload empty")
  result = "preview-" & $payload.len

proc fakeAuditWrite(auditPath: string; line: string) =
  if auditPath == "audit-fail":
    raise newException(OSError, "audit write failed")

proc buildPreviewPayload(pages: seq[string]; pageIndex: int): seq[byte] =
  if pageIndex >= pages.len:
    raise newException(ValueError, "page index out of bounds")
  let page = pages[pageIndex]
  if page.len == 0:
    raise newException(IOError, "selected page was empty")
  result = @(page.toOpenArrayByte(0, page.high))

proc processOne(path: string; pageIndex: int): string =
  let pages = fakeReadPages(path)
  let payload = buildPreviewPayload(pages, pageIndex)
  result = fakeUpload(payload)

proc writeAuditLine(auditPath: string; line: string) =
  try:
    fakeAuditWrite(auditPath, line)
  except OSError:
    raise newException(IOError, "audit write failed for " & auditPath & ": " &
        getCurrentExceptionMsg())

proc runBatch(paths: seq[string]; pageNo: Positive; auditPath: string): BatchSummary =
  let pageIndex = pageNo.int - 1
  result.items = @[]
  for path in paths:
    try:
      let previewId = processOne(path, pageIndex)
      result.items.add PreviewItem(
        path: path,
        success: true,
        previewId: previewId,
        errorMsg: ""
      )
      inc result.okCount
    except CatchableError:
      let msg = getCurrentExceptionMsg()
      writeAuditLine(auditPath, path & ": " & msg)
      result.items.add PreviewItem(
        path: path,
        success: false,
        previewId: "",
        errorMsg: msg
      )
      inc result.failCount
```

## Key points

- `processOne` stays straight-line and lets failures propagate.
- `runBatch` converts processing failures into ordered per-item outcomes.
- `writeAuditLine` translates audit failure to `IOError` and adds the audit path.
- If audit writing fails, the translated error escapes `runBatch`; the batch cannot safely report that item.
