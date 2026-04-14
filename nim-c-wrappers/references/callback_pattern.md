Minimal pattern for C callbacks in Nim.

## Pattern

```nim
type
  WriteCallback* = proc(buffer: ptr char, size: csize_t, nitems: csize_t, userdata: pointer): csize_t {.cdecl.}

proc bodyWriteCb(buffer: ptr char, size: csize_t, nitems: csize_t, userdata: pointer): csize_t {.cdecl.} =
  let total = int(size * nitems)
  if total <= 0:
    result = 0
  else:
    let body = cast[ptr string](userdata)
    if body.isNil:
      result = csize_t(total)
    else:
      let start = body[].len
      body[].setLen(start + total)
      copyMem(addr body[][start], buffer, total)
      result = csize_t(total)
```

## Rules

* Use `{.cdecl.}` for all C callbacks
* `userdata` is a raw pointer — you define its type
* Cast back using the exact original type (`ptr T`)
* The pointed memory must remain valid for the entire callback lifetime
* Do not pass temporaries or moved values
* Do not use closures
