---
name: nim-error-handling
description: Design Nim error propagation, exception boundaries, and parse-failure behavior.
---

# Nim Error Handling

Use this skill when choosing between exceptions, boundary translation, parse helpers,
or multi-step pipeline failure handling.

## Core rules

- Do not introduce ad-hoc result objects that pass only `ok`, `kind`, and `message` between steps.
- Do not add custom exception types unless callers handle them differently from existing exceptions.
- Catch errors only where you can recover, translate across a boundary, or add required context.
- Raise clear, bounded, actionable errors.
- Do not silently swallow exceptions.
- Prefer exception propagation over manual result-wrapper plumbing for recoverable errors.
- Let stepwise pipeline errors bubble until the boundary where they become actionable output.
- Convert low-level errors at module boundaries when needed for context or contracts.
- For bool-return parse helpers, catch `CatchableError` once at the helper boundary and return `false`.

## Don't

```nim
type
  StepResult = object
    ok: bool
    kind: string
    message: string

proc renderPage(): StepResult =
  discard
```

## Do

```nim
type
  Bitmap = object
    width: int
    height: int
    pixels: pointer

  PageTask = object
    page: int
    webpBytes: seq[byte]

proc renderPageBitmap(page: int): Bitmap =
  result = rendererRender(page)
  if result.width <= 0 or result.height <= 0 or result.pixels.isNil:
    raise newException(IOError, "invalid bitmap state from renderer")

proc encodePageBitmap(bitmap: Bitmap): seq[byte] =
  result = encodeWebp(bitmap)
  if result.len == 0:
    raise newException(IOError, "encoded WebP output was empty")

proc buildPageTask(page: int): PageTask =
  let bitmap = renderPageBitmap(page)
  let webpBytes = encodePageBitmap(bitmap)
  result = PageTask(page: page, webpBytes: webpBytes)

proc runOrchestrator(pages: seq[int]) =
  for page in pages:
    try:
      submit(buildPageTask(page))
    except CatchableError:
      recordPageFailure(page, boundedErrorMessage(getCurrentExceptionMsg()))

proc parseFirstCallArgs*[T](x: ChatCreateResult; dst: var T; i = 0): bool =
  result = false
  try:
    dst = fromJson(x.firstCallArgs(i), T)
    result = true
  except CatchableError:
    result = false
```

```nim
try:
  discard doWork()
except CatchableError:
  raise newException(IOError, "doWork failed: " & getCurrentExceptionMsg())
```
