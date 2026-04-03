---
name: nim-doc-comments
description: Write Nim doc comments in the standard source layout and verify rendered docs with `nim doc`.
---

# Nim Doc Comments

Use this skill when writing or improving documentation comments in Nim source files.

Keep the scope narrow:

- Write clear doc comments for public Nim APIs.
- Place comments where Nim code and `nim doc` expect them.
- Use `nim doc` to verify rendered output.
- Add `runnableExamples:` only if the user asks for them or the local codebase already uses them.

## Placement rules

Follow real stdlib layout such as `std/strutils` and `std/options`.

### Module docs

- Put module docs at the top of the file, before imports and declarations.
- Use either consecutive `##` lines or a block doc comment with `##[ ... ]##` for longer module overviews.
- If examples are needed, put a top-level `runnableExamples:` block after the module docs.

### Proc, func, iterator, template, and converter docs

- Attach the doc comment to the declaration itself.
- In standard Nim source layout, put the `##` lines immediately after the signature line and before the implementation body.
- If using `runnableExamples:`, place it after the doc text and before the implementation statements.

### Type, object, enum, const, and let docs

- For declarations inside `type`, `const`, and similar blocks, attach docs to the declaration line itself.
- The common Nim pattern is an inline trailing doc comment, for example:
  `Hash* = int ## A hash value.`
- If the docs need more than one line, continue them on following indented `##` lines aligned under the declaration.
- For object types, aliases, distinct types, enum types, enum values, consts, and lets, prefer declaration-attached docs over a standalone doc block above the symbol.
- For fields and enum values, keep docs on the same line when they are short; use aligned continuation `##` lines only when needed.

## What to document

- Document exported symbols first.
- Add module-level docs when the public purpose is not obvious from the module name.
- Document behavior, contracts, and usage constraints.
- Mention errors, mutation, borrowing, ownership, or side effects when they matter to callers.
- Skip comments that only restate the symbol name or obvious type information.

## Writing style

- Start with a short summary sentence.
- Explain what the API does and how callers should use it.
- Prefer concrete behavior over implementation detail.
- Keep comments short, factual, and source-focused.
- Use short paragraphs and compact bullet lists when they improve scanning.
- Use `See also` only when there is a genuinely related API worth linking.

## `runnableExamples`

- Do not add `runnableExamples:` by default.
- Add them only when the user explicitly asks for examples, or when the surrounding codebase already documents similar APIs that way.
- Keep examples minimal and executable.
- Use examples to show non-obvious usage, not trivial happy-path calls.
- If an example needs compile flags, use the parameterized form, for example `runnableExamples("-d:flag")`.

## `nim doc`

- Run `nim doc path/to/module.nim` to render the module documentation.
- Use the rendered output to verify structure, symbol grouping, links, and comment readability.
- Fix the source comments when rendering looks wrong; do not edit generated output.

## Examples

### Module docs

```nim
## Utilities for parsing and validating service configuration values.
##
## Exported helpers in this module raise `ValueError` for invalid user input.

import std/strutils
```

```nim
##[
Utilities for parsing and validating service configuration values.

Exported helpers in this module raise `ValueError` for invalid user input.
]##

import std/strutils
```

### Proc docs

```nim
proc encodeToken*(value: Token): string =
  ## Encodes `value` as a compact URL-safe token.
  ##
  ## Raises `ValueError` if `value` cannot be represented in the target format.
  discard
```

```nim
proc encodeToken*(value: Token): string =
  ## Encodes `value` as a compact URL-safe token.
  runnableExamples:
    let token = encodeToken(sampleToken())
    doAssert token.len > 0
  discard
```

### Type docs

```nim
type
  RequestContext* = object ## Parsed request with validated headers and route parameters.
    headers*: HttpHeaders ## Request headers.
    routeParams*: Table[string, string] ## Decoded route parameters.
```

```nim
type
  Tree* = object ## Mutable builder used to assemble output.
                 ## Copying shares the payload until mutation detaches it.
    p: ptr TreePayload
```

```nim
type
  XmlNodeKind* = enum ## Different kinds of XML nodes.
    xnText,           ## A text element.
    xnElement,        ## An element with zero or more children.
    xnComment         ## An XML comment.
```

### Const docs

```nim
const
  DefaultPort* = 443 ## Default HTTPS port for outbound requests.
```

```nim
const
  HeaderLimit* = 10_000 ## Maximum accepted header bytes.
  DefaultPort* = 443    ## Default HTTPS port for outbound requests.
```

```nim
const
  HeaderLimit* = 10_000 ## Maximum accepted header bytes.
                        ## Increase only if the protocol boundary requires it.
```

## Workflow

1. Identify the exported symbols that form the public API.
2. Add or improve doc comments in source.
3. Add `runnableExamples:` only if requested or clearly established by the local codebase.
4. Run `nim doc` on the affected module.
5. Review and tighten the source comments until the rendered docs read cleanly.
