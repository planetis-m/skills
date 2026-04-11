Simple default patterns for readable Nim code.

# Examples

## Imports

Prefer grouped imports for broad use and narrow `from` imports for a small API slice.

```nim
import std/[strutils, parseutils, uri]

from std/paths import Path, isAbsolute
```

## Callable kind

Default to `proc`. Use `func` for obviously pure helpers. Use `template` only for tiny substitutions. Do not use `method` unless runtime dispatch is required. Keep reusable helpers top-level; use nesting for very local logic or intentional closures.

```nim
func isAbsolutePath(path: Path): bool =
  result = isAbsolute(path)
```

```nim
template asString(x): string =
  string(x)
```

## Calls And Result Style

Prefer compact wrapped calls and one clear normal path.

```nim
proc buildMessage(name: string; count: int; urgent: bool): string =
  result = formatMessage(name, count,
    urgent = urgent,
    includeFooter = true)
```

## Locals And Fields

Use `let` for stable values, `var` for mutated state, and group related fields when it improves readability.

```nim
let item = items[idx]
var total = 0
```

```nim
type
  ParseConfig = object
    maxCount, retryLimit: int
    strict: bool
```

## Object Constructors

When a type has sensible defaults, set only the fields you want to override.

```nim
type
  WorkerState = object
    retryLimit: int = 3
    stopRequested: bool
    label: string = "worker"

proc initWorkerState(): WorkerState =
  WorkerState()

proc initNamedWorker(label: string): WorkerState =
  WorkerState(label: label)
```

# Key points

- Keep the rules simple and apply them consistently.
- Use `proc`, `func`, and `template` for different jobs.
- Prefer compact wrapping, `let` by default, one normal success path, and constructors that override only the fields that matter.
