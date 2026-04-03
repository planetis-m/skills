---
name: nim-api-design
description: Design Nim APIs with clear contracts, coherent data models, and accessor behavior.
---

# Nim API Design

Use this skill when reviewing or implementing public-facing Nim APIs, helper contracts,
data shapes, or accessor behavior.

## Scope

- Proc and template contracts
- Result and error-surface design
- Data-model choices such as object vs tuple
- Accessor signatures and borrowing behavior

## Core rules

- Do not weaken proc contracts (for example, `Positive` -> `int`) and then add manual checks.
- Do not add redundant runtime checks that restate existing type or proc contracts unless required by a boundary.
- Use named `object` types for semantic data.
- Use tuples for short local values only.
- If a tuple grows beyond a small pair or triple, create a named object.

## Accessor design

- Treat accessor contracts as strict: invalid index and missing required data should raise `ValueError`.
- Route accessor errors through one shared helper proc marked `{.noinline, noreturn.}` for consistent behavior.
- Use `lent T` for read accessors that borrow from object fields.
- Add `var T` accessor overloads only for mutable reference-like results such as `string` and `seq[...]` when mutation is part of the API.
- Do not add `var` overloads for simple scalar outputs such as `int`, `float`, `bool`, or enums.
- In `lent` and `var` accessors, prefer direct indexing from the owner object; avoid temporary locals that can trigger escaping-borrow issues.

## Do

```nim
type
  RenderResult = object
    payload: seq[byte]
    warnings: seq[string]

proc raiseAccessorValueError(message: string) {.noinline, noreturn.} =
  raise newException(ValueError, message)

proc firstCallId*(x: ChatCreateResult; i = 0): lent string {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.tool_calls.len == 0:
    raiseNoToolCallsAtChoice(i)
  result = x.choices[i].message.tool_calls[0].id

proc firstCallId*(x: var ChatCreateResult; i = 0): var string {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.tool_calls.len == 0:
    raiseNoToolCallsAtChoice(i)
  result = x.choices[i].message.tool_calls[0].id
```

## Don't

```nim
proc render(): tuple[ok: bool, payload: seq[byte], errorMessage: string] =
  discard

proc firstCallId*(x: ChatCreateResult; i = 0): string =
  result = ""
  if x.hasToolCalls(i):
    result = x.choices[i].message.tool_calls[0].id
```
