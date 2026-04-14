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

## Key points

* Callbacks must be `{.cdecl.}` — C expects a plain function pointer, not a Nim closure.
* `userdata` is a raw pointer passed through C and must be cast back to the original type.
* The object behind `userdata` must remain alive for the entire callback lifetime.
* Do not pass stack temporaries as userdata.
* Do not pass freed or invalid pointers as userdata.
* `setLen` is allowed even if it reallocates the internal buffer; only the buffer moves, not the string header.
