Module-level doc comment patterns.

## Line-style module docs

```nim
## Utilities for parsing and validating service configuration values.
##
## Exported helpers in this module raise `ValueError` for invalid user input.

import std/strutils
```

## Block-style module docs

```nim
##[
Utilities for parsing and validating service configuration values.

Exported helpers in this module raise `ValueError` for invalid user input.
]##

import std/strutils
```

## Top-level runnableExamples after module docs

```nim
## Module with example.

runnableExamples:
  doAssert 1 + 1 == 2

proc placeholder*() = discard
```

### Key points

- Module docs must appear before any imports or declarations.
- Both `##` line and `##[ ... ]##` block syntax render as `module-desc` in the HTML.
- Top-level `runnableExamples:` after module docs compiles and executes during `nim doc`.
