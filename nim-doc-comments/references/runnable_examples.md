runnableExamples placement and parameterized flags.

## Basic runnableExamples in a proc

```nim
proc encodeToken*(value: Token): string =
  ## Encodes `value` as a compact URL-safe token.
  runnableExamples:
    let token = encodeToken(sampleToken())
    doAssert token.len > 0
  discard
```

## Parameterized compile flags

```nim
proc flagged*(): string =
  ## Uses a compile-time define.
  runnableExamples("-d:myflag"):
    when defined(myflag):
      doAssert true
    else:
      doAssert false
  result = "ok"
```

### Key points

- Place `runnableExamples:` after doc text, before implementation statements.
- `nim doc` compiles and runs all examples; a failing `doAssert` causes `nim doc` to exit non-zero.
- Use `runnableExamples("-d:flag")` to pass compile flags.
- Only add examples when requested or when the codebase already uses them.
