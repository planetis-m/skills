Minimal pattern for C callbacks in Nim.

## Pattern

```nim
type
  WriteCallback* = proc(buffer: ptr char, size: csize_t, nitems: csize_t,
    userdata: pointer): csize_t {.cdecl.}

proc bodyWriteCb(buffer: ptr char, size: csize_t, nitems: csize_t,
    userdata: pointer): csize_t {.cdecl.} =
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

## Passing Nim closure state via rawProc/rawEnv

When the callback needs captured Nim state, extract the closure's function
pointer and environment with `rawProc`/`rawEnv`. The raw proc expects the
environment pointer as its last argument, so the C callback signature must
put `userdata` last:

```nim
type
  CallbackFn = proc(code: cint; userdata: pointer) {.cdecl.}
  CallbackState = ref object
    total: int
  CallbackRegistration = object
    fn: CallbackFn
    userdata: pointer

proc makeCallback(state: CallbackState): proc(code: cint) =
  result = proc(code: cint) =
    state.total += int(code)

proc registerCallback(cb: proc(code: cint)): CallbackRegistration =
  let rp = rawProc(cb)
  let re = rawEnv(cb)
  if not re.isNil:
    GC_ref(cast[RootRef](re))
  result = CallbackRegistration(fn: cast[CallbackFn](rp), userdata: re)

proc unregisterCallback(reg: CallbackRegistration) =
  if not reg.userdata.isNil:
    GC_unref(cast[RootRef](reg.userdata))
```

## Key points

- Callbacks must be `{.cdecl.}` — C expects a plain function pointer, not a Nim closure.
- `userdata` is a raw pointer passed through C and must be cast back to the original type.
- The object behind `userdata` must remain alive for the entire callback lifetime.
- Do not pass stack temporaries as userdata.
- Do not pass freed or invalid pointers as userdata.
- `setLen` is allowed even if it reallocates the internal buffer; only the buffer moves, not the string header.
- When using `rawProc`/`rawEnv`, the raw proc expects the environment as the last argument. The C callback signature must match.
- `GC_ref` the environment pointer before passing it to C so it survives after the closure is destroyed; `GC_unref` after the callback is unregistered.
