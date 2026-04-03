---
name: nim-style-guide
description: Enforce idiomatic, readable Nim with formatting, naming, call-style, control-flow, and local declaration conventions.
---

# Nim Style Guide

Use this guide when writing or refactoring Nim.
Keep it focused on readability, consistency, and presentation.

## Non-negotiable rules

- `continue` is banned.
- Nested `type` declarations are banned.
- Do not use early `return` only to reduce nesting.
- Do not rewrite normal helper procs into templates unless the helper is a single expression.
- If a helper uses `if`, `case`, loops, `try`, or `block`, it must be a `proc`.

## 1. Formatting

### Rules

- Indent with 2 spaces. No tabs.
- Keep lines reasonably short (target <= 100 chars; prefer about 90-100).
- Do not manually align columns with extra spaces.
- Use `a..b` (not `a .. b`) unless spacing is needed for clarity with unary operators.
- For wrapped declarations and conditions, indent continuation lines one extra level.
  Use +4 spaces relative to the wrapped line's base indent.

### Do

```nim
type
  Handle = object
    fd: int
    valid: bool
```

```nim
proc enterDrainErrorMode(ctx: NetworkWorkerContext; message: string;
    multi: var CurlMulti; active: var Table[uint, RequestContext];
    retryQueue: var seq[RetryItem]; idleEasy: var seq[CurlEasy]) =
  discard
```

```nim
if WebPConfigInitInternal(addr config, WEBP_PRESET_DEFAULT, quality,
    WEBP_ENCODER_ABI_VERSION) == 0:
  raise newException(ValueError, "WebPConfigInitInternal failed")
```

### Don't

```nim
type
  Handle    = object
    fd       : int
    valid    : bool
```

```nim
proc enterDrainErrorMode(ctx: NetworkWorkerContext; message: string;
  multi: var CurlMulti; active: var Table[uint, RequestContext];
  retryQueue: var seq[RetryItem]; idleEasy: var seq[CurlEasy]) =
  discard
```

```nim
if WebPConfigInitInternal(addr config, WEBP_PRESET_DEFAULT, quality,
  WEBP_ENCODER_ABI_VERSION) == 0:
  raise newException(ValueError, "WebPConfigInitInternal failed")
```

## 2. Naming

### Rules

- Types: `PascalCase`.
- Procs, templates, vars, and fields: `camelCase`.
- Enum values: prefixed for non-pure enums (`pcFile`), PascalCase for pure enums.
- Use normal word casing: `parseUrl`, `httpStatus`.
- Prefer subject-verb names: `fileExists`, not `existsFile`.

### Do

```nim
type
  PathComponent = enum
    pcFile
    pcDir

proc fileExists(path: string): bool = discard
```

### Don't

```nim
proc existsFile(path: string): bool = discard
proc parseURL(text: string): string = discard
```

## 3. Proc Style and Call Style

### Rules

- Default to `proc`.
- `template` is allowed only for tiny expression substitutions.
- A template body should be exactly one expression.
- Never use expression templates with `block:` wrappers to hide statements.
- Use `macro` only when syntax transformation is required.
- For multi-line calls, prefer compact wrapped calls over one-argument-per-line blocks.
- This call-formatting rule is for proc and function calls, not object constructors.
- Prefer UFCS for accessor-style APIs when it reads like field access (`bitmap.width`).

### Do

```nim
finalizeOrRetry(ctx, retryQueue, rng, req.task, req.attempt,
  retryable = true, kind = NetworkError,
  message = boundedErrorMessage(getCurrentExceptionMsg()))
```

```nim
proc readBitmapMetrics(bitmap: PdfBitmap): tuple[w, h: int] =
  result = (bitmap.width, bitmap.height)
```

### Don't

```nim
template nextReady(): bool =
  (block:
    let idx = slotIndex(nextToWrite, k)
    pending[idx].isSome() and pending[idx].get() == nextToWrite
  )
```

```nim
finalizeOrRetry(
  ctx,
  retryQueue,
  rng,
  req.task,
  req.attempt,
  retryable = true,
  kind = NetworkError,
  message = boundedErrorMessage(getCurrentExceptionMsg())
)
```

## 4. Control Flow and Returns

### Rules

- Prefer structured control flow (`if/elif/else`, explicit loop conditions).
- `continue` is banned; structure branches instead.
- Use early `return` for real guard exits (found, fatal, precondition), not as default style.
- Do not early-return for empty or zero normal inputs; keep one normal flow and let loop bounds naturally produce empty output.
- Keep one clear normal success path.
- Use `result = ...` for normal flow.
- Keep return style consistent inside each proc.

### Do

```nim
proc findUser(users: seq[string]; target: string): int =
  for i, user in users:
    if user == target:
      return i
  result = -1
```

```nim
proc process(values: seq[int]): int =
  for value in values:
    if value >= 0:
      result.inc(value)
```

```nim
proc allPagesSelection(totalPages: int): seq[int] =
  result = @[]
  for page in 1 .. totalPages:
    result.add(page)
```

### Don't

```nim
proc process(values: seq[int]): int =
  for value in values:
    if value < 0:
      continue
    result.inc(value)
```

```nim
proc allPagesSelection(totalPages: int): seq[int] =
  if totalPages <= 0:
    return @[]
  result = newSeqOfCap[int](totalPages)
  for page in 1 .. totalPages:
    result.add(page)
```

## 5. Type Presentation

### Rules

- Never declare `type` blocks inside procs.
- Group related fields with the same type when it improves readability (`a, b: int`).
- Prefer object-construction syntax (`TypeName(field: ...)`) over field-by-field `result.field = ...`.

### Do

```nim
type
  OrchestratorState = object
    written, okCount, errCount: int
    nextToRender, nextToWrite: int
```

```nim
proc initWorkerState(seed: int): WorkerState =
  WorkerState(
    active: initTable[uint, RequestContext](),
    retryQueue: @[],
    idleEasy: @[],
    rng: initRand(seed),
    stopRequested: false
  )
```

### Don't

```nim
proc initWorkerState(seed: int): WorkerState =
  result.active = initTable[uint, RequestContext]()
  result.retryQueue = @[]
  result.idleEasy = @[]
  result.rng = initRand(seed)
  result.stopRequested = false
```

## 6. Local Declarations and Imports

### Rules

- Use `let` by default.
- Use `var` only for mutated values.
- Keep declarations close to first use.
- Prefer `std/...` imports for standard library modules.

### Do

```nim
let page = pages[idx]
var attempts = 0
```
