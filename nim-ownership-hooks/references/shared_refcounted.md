# Shared / refcounted handle

Multiple variables share ownership of one heap resource. The last owner destroys it.

This repo uses the **inverted counter**: `0` means exclusively owned, `>0` means shared. Copying increments; the last destroy frees.

## Refcounted handle — separate counter

Use when wrapping an opaque C object whose layout you don't control. The reference count lives in its own heap cell alongside the object pointer.

```nim
type
  Wrapper = object
    obj: ptr Obj
    rc: ptr int

proc `=destroy`*(dest: Wrapper) =
  if dest.obj != nil:
    if dest.rc[] == 0:
      dealloc(dest.rc)
      destroyObj(dest.obj)
    else:
      dec dest.rc[]

proc `=wasMoved`*(dest: var Wrapper) =
  dest.obj = nil
  dest.rc = nil

proc `=dup`*(src: Wrapper): Wrapper =
  if src.obj != nil: inc src.rc[]
  result.obj = src.obj
  result.rc = src.rc

proc `=copy`*(dest: var Wrapper; src: Wrapper) =
  if src.obj != nil: inc src.rc[]
  `=destroy`(dest)
  dest.obj = src.obj
  dest.rc = src.rc

proc create(s: string): Wrapper =
  Wrapper(obj: createObj(cstring(s)),
          rc: cast[ptr int](alloc0(sizeof(int))))
```

Key points:
- `rc` is `ptr int` (heap-allocated) so all copies share the same counter cell
- `alloc0` initializes the counter to `0` — one unique owner
- `=copy` increments source's counter **before** destroying dest — this protects self-assignment: inc→dec balances, no free
- No self-assignment guard needed — increment-before-destroy makes `x = x` safe
- No `{.nodestroy.}` on `=dup` — the counter balances the implicit return-path destroy
- When the type may cross thread boundaries, use `allocShared`/`deallocShared` for both `obj` and `rc`

## SharedPtr — packed counter, generic, atomic

Use for shared ownership of Nim values. The value and counter are packed in one allocation. Atomic operations make it safe across threads.

```nim
type
  SharedPtr*[T] = object
    val: ptr tuple[value: T, counter: Atomic[int]]

proc `=destroy`*[T](p: SharedPtr[T]) =
  if p.val != nil:
    if p.val.counter.fetchSub(1, moAcquireRelease) == 0:
      `=destroy`(p.val.value)
      deallocShared(p.val)

proc `=wasMoved`*[T](p: var SharedPtr[T]) =
  p.val = nil

proc `=dup`*[T](src: SharedPtr[T]): SharedPtr[T] =
  if src.val != nil:
    discard fetchAdd(src.val.counter, 1, moRelaxed)
  result.val = src.val

proc `=copy`*[T](dest: var SharedPtr[T]; src: SharedPtr[T]) =
  if src.val != nil:
    discard fetchAdd(src.val.counter, 1, moRelaxed)
  `=destroy`(dest)
  dest.val = src.val

proc newSharedPtr*[T](val: sink Isolated[T]): SharedPtr[T] {.nodestroy.} =
  result.val = cast[typeof(result.val)](
    allocShared(sizeof(result.val[])))
  result.val.counter.store(0, moRelaxed)
  result.val.value = extract val
```

Key points:
- `fetchSub` returns the **old** value — when it returns `0`, we were the last owner and must free
- `=copy` increments **before** destroying dest, same self-assign protection as the separate-counter pattern
- `allocShared`/`deallocShared` required because atomic refcounting implies cross-thread use
- `newSharedPtr` uses `{.nodestroy.}` because `result` is being built, not returned from a share
- Counter starts at `0` — one unique owner — matching the inverted convention
