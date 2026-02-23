---
name: wrapper
description: Guidelines for building idiomatic Nim wrappers on top of C FFI bindings.
---

# C→Nim Manual Wrapping Skills

## 1. Purpose
A C→Nim wrapper exposes a C library to Nim while preserving ABI correctness and offering an idiomatic Nim API. The goals are:

- ABI correctness: exact layouts, calling conventions, and signatures.
- Nim ergonomics: safer, clearer, and more “Nim-like” usage.

**Recommended two-layer design:**

1. **Raw FFI layer**: faithful bindings to C with minimal interpretation.
2. **Ergonomic Nim layer**: safe, friendly wrappers that hide pitfalls and add conveniences.

Keep the raw layer stable and thin. Build the ergonomic layer on top so you can adjust usability without changing the ABI surface.

---

## 2. Project Layout & Module Strategy
Split modules by library domain and keep raw bindings isolated from idiomatic wrappers.

**Suggested module pattern (conceptual):**

- `lib_raw_*`: raw FFI modules (structs, typed constants, `importc` procs)
- `lib_*`: ergonomic modules (overloads, helpers, resource management)

**Public vs private symbols:**

- Export raw symbols only if needed for advanced users.
- Re-export selected symbols from ergonomic modules to provide a clean public API.
- Keep internal helpers private to avoid API bloat.

**When splitting a large library:**

- Mirror the C header structure (by subsystem).
- Avoid cyclic imports by centralizing shared types in a `lib_raw_types` module.
- Keep public surface small and predictable.

---

## 3. Wrapper Lessons (Grounded in Repo History)

- Keep wrappers minimal: remove unused APIs, fields, and helpers so the binding reflects only what the project needs.
- Prefer `incompleteStruct` for C structs and list only the fields you actually use. This reduces ABI risk and keeps bindings aligned with real usage.
- Avoid stateful “isOpen/used” flags on stack objects with destructors: stack addresses are not stable and destructor timing is too implicit for multi‑step C workflows.
- When a resource has a strict init/write/finish sequence, prefer single‑call convenience wrappers (or explicit `try/finally` blocks) over stateful objects.
- Prefer exceptions in the ergonomic layer over manual result wrappers that only carry `ok`/`kind`/`message`.
- Do not introduce custom exception types unless a caller genuinely handles that type differently.
- Catch low-level errors only at meaningful boundaries:
  - where you translate C return codes/pointers to Nim exceptions, or
  - where you map an exception to a final domain result.
  Otherwise, let exceptions propagate.

**Error-flow example (preferred):**

```nim
proc renderPage(doc: PdfDocument; page: int): PdfBitmap =
  result = renderPageAtScale(loadPage(doc, page - 1), 2.0)

proc runPage(doc: PdfDocument; page: int) =
  try:
    let bitmap = renderPage(doc, page)
    submit(bitmap)
  except CatchableError:
    emitPageError(page, "PdfError", getCurrentExceptionMsg())
```

## 4. Naming & API Conventions (Idiomatic Nim)

**Prefix stripping:**

- Remove common prefixes like `LIB_`, `foo_`, `FOO_` when they don’t add clarity.
- Preserve names when they disambiguate or match common documentation terminology.

**Casing rules:**

- Types/objects/distincts: `PascalCase`
- Procs/vars: `lowerCamelCase`
- Raw binding constants: keep upstream C-style names (for example, `CURLE_OK`).

**When to keep original C names:**

- Well-known API names that are part of the library’s identity.
- Names that would collide after stripping prefixes.
- When upstream docs refer to exact names heavily.

**Reserved names / keywords:**

- Add a suffix like `*` in docs but in code use a consistent rename (e.g., `type` → `typ`, `addr` → `address`).
- Consider `importc: "..."` to preserve the C name while using a safe Nim name.

---

## 5. FFI Mechanics Cheatsheet

**Core pragmas:**

- `importc`: bind a Nim symbol to a C symbol.
- `cdecl`: default C calling convention (use `stdcall` or others if C library requires).
- `header`: specify header for C compilation (static linking scenarios).
- `dynlib`: resolve symbols from a shared library at runtime.

**Static vs dynamic linking:**

- **Static**: use `{.header.}` and link the C objects at build time.
- **Dynamic**: use `{.dynlib.}` and optionally specify a library name with `dynlib: "libfoo"`.

**Platform/architecture conditionals:**

- Use `when defined(windows):` etc. for library names and ABI differences.

**Don’t accidentally change ABI rules:**

- Don’t reorder fields in structs.
- In raw bindings for this repo, avoid Nim `enum`; use typed integer aliases + `const` values.
- Don’t “helpfully” convert pointer types in the raw layer.

---

## 6. C→Nim Type Mapping (Table + Examples)

### Integer Types

| C Type               | Nim Type     | Notes                                                 |
| -------------------- | ------------ | ----------------------------------------------------- |
| `char`               | `cchar`      | Exactly C `char` (signedness is platform-dependent)   |
| `signed char`        | `cschar`     | Always `int8`                                         |
| `unsigned char`      | `uint8`      | `cuchar` exists but **deprecated**                    |
| `short`              | `cshort`     | Always `int16`                                        |
| `unsigned short`     | `cushort`    | Always `uint16`                                       |
| `int`                | `cint`       | Always `int32`                                        |
| `unsigned int`       | `cuint`      | Always `uint32`                                       |
| `long`               | `clong`      | ABI-sized (`int32` on Windows, `int` on LP64/ILP32)   |
| `unsigned long`      | `culong`     | ABI-sized (`uint32` on Windows, `uint` on LP64/ILP32) |
| `long long`          | `clonglong`  | Always `int64`                                        |
| `unsigned long long` | `culonglong` | Always `uint64`                                       |
| `size_t`             | `csize_t`    | Alias for `uint` (ABI-sized)                          |
| `intptr_t`           | `int`        | Pointer-sized signed                                  |
| `uintptr_t`          | `uint`       | Pointer-sized unsigned                                |

### Floating-Point Types

| C Type        | Nim Type      | Notes                          |
| ------------- | ------------- | ------------------------------ |
| `float`       | `cfloat`      | Always `float32`               |
| `double`      | `cdouble`     | Always `float64`               |
| `long double` | `clongdouble` | Not truly supported by codegen |

### Pointer & String Types

| C Type        | Nim Type       | Notes                         |
| ------------- | -------------- | ----------------------------- |
| `void*`       | `pointer`      | Untyped raw pointer           |
| `T*`          | `ptr T`        | Nullable by default           |
| `T**`         | `ptr ptr T`    | Direct pointer nesting        |
| `char*`       | `cstring`      | NUL-terminated C string       |
| `const char*` | `cstring`      | Conventionally read-only      |
| `char**`      | `cstringArray` | `ptr UncheckedArray[cstring]` |

### Structs and alignment

- Use `object` with fields in C order.
- Use `packed` only if C headers specify packing.
- If alignment is unclear, add `static: doAssert sizeof(T) == ...` in tests.

### Arrays

- Fixed-size array in struct: `array[N, T]`
- Pointer+length: `ptr T` + `csize_t`
- Raw buffers: `ptr UncheckedArray[T]`

### Opaque handles

- Represent as `pointer` or `ptr OpaqueObj` where `OpaqueObj` is an empty object.

**Example: fixed array in struct**

C:
```c
typedef struct LIB_Color {
  unsigned char rgba[4];
} LIB_Color;
```

Raw Nim:
```nim
type
  LibColor* {.importc: "LIB_Color".} = object
    rgba*: array[4, cuchar]
```

---

## 6. Wrapping C Enum-Like Values, Flags, and Macros

For this project’s raw binding layer, do not model C enums with Nim `enum`.
Use a typed integer alias and define only the constants the code actually needs.

**Enum-like values (project style):**

- Define the C enum storage type as `cint`/`cuint` alias (or a `distinct` int when useful).
- Add minimal `const` values used by the wrapper/orchestrator.
- Keep names close to upstream C names to reduce lookup friction.

```c
typedef enum LIB_Mode {
  LIB_ModeA = 0,
  LIB_ModeB = 2,
  LIB_ModeC = 3
} LIB_Mode;
```

```nim
type
  LibMode* = cint

const
  LIB_ModeA* = LibMode(0)
  LIB_ModeB* = LibMode(2)
```

**Bitflags (project style):**

- Use integer/`distinct` integer flag types with bitwise helpers.
- Do not use `set[Enum]` in raw bindings.

```nim
type
  LibFlags* = distinct cuint

const
  LIB_FLAG_READ* = LibFlags(1'u32 shl 0)
  LIB_FLAG_WRITE* = LibFlags(1'u32 shl 1)

proc has*(flags: LibFlags; flag: LibFlags): bool {.inline.} =
  (cuint(flags) and cuint(flag)) != 0'u32
```

**Macros:**

- Simple numeric macros -> `const`.
- Function-like macros -> wrap as inline procs or templates.
- If a macro depends on `sizeof` or expressions with side effects, prefer a Nim template.

---

## 7. Wrapping Functions

**Raw signatures must match C exactly.**

### Example: create/destroy (Automatic Resource Management)

C:

```c
typedef struct LIB_Handle LIB_Handle;
LIB_Handle* LIB_Create(int width, int height);
void LIB_Destroy(LIB_Handle* h);
```

Raw Nim:

```nim
type
  LibHandle* {.importc: "LIB_Handle".} = object

proc libCreate*(width, height: cint): ptr LibHandle
  {.importc: "LIB_Create", cdecl.}
proc libDestroy*(h: ptr LibHandle)
  {.importc: "LIB_Destroy", cdecl.}
```

Ergonomic Nim (Move-Only):

```nim
type
  Handle* = object
    raw: ptr LibHandle

proc `=destroy`*(h: Handle) =
  if h.raw != nil:
    libDestroy(h.raw)

proc `=wasMoved`*(h: var Handle) = h.raw = nil

proc `=sink`*(dest: var Handle; src: Handle) =
  `=destroy`(dest)
  dest.raw = src.raw

proc `=copy`*(dest: var Handle; src: Handle) {.error.}
proc `=dup`*(src: Handle): Handle {.error.}

proc initHandle*(width, height: int): Handle =
  result.raw = libCreate(cint width, cint height)
  if result.raw.isNil:
    raise newException(ValueError, "Failed to create handle")
```

### Example: in/out parameters

C:
```c
int LIB_GetSize(LIB_Handle* h, int* w, int* hgt);
```

Raw Nim:
```nim
proc libGetSize*(h: ptr LibHandle; w, hgt: ptr cint): cint
  {.importc: "LIB_GetSize", cdecl.}
```

Ergonomic Nim:
```nim
proc size*(h: Handle): tuple[w, hgt: int] =
  var wC, hC: cint
  if libGetSize(h.raw, addr wC, addr hC) != 0:
    raise newException(IOError, "LIB_GetSize failed")
  (int wC, int hC)
```

### Example: string parameters

C:
```c
int LIB_SetName(LIB_Handle* h, const char* name);
```

Raw Nim:
```nim
proc libSetName*(h: ptr LibHandle; name: cstring): cint
  {.importc: "LIB_SetName", cdecl.}
```

Ergonomic Nim:
```nim
proc setName*(h: Handle; name: string) =
  if libSetName(h.raw, name.cstring) != 0:
    raise newException(ValueError, "LIB_SetName failed")
```

---

## 8. Callbacks / Function Pointers

**Declare callback types with `cdecl`:**

```c
typedef void (*LIB_LogFn)(void* userdata, const char* msg);
void LIB_SetLogFn(LIB_LogFn fn, void* userdata);
```

Raw Nim:
```nim
type
  LibLogFn* = proc(userdata: pointer; msg: cstring) {.cdecl.}

proc libSetLogFn*(fn: LibLogFn; userdata: pointer)
  {.importc: "LIB_SetLogFn", cdecl.}
```

Ergonomic Nim:

- **Avoid capturing closures.** C expects a plain function pointer.
- Store state in a global table keyed by `userdata` if needed.

```nim
proc logBridge(userdata: pointer; msg: cstring) {.cdecl.} =
  # Convert and dispatch safely
  let s = $msg
  discard s

proc setLogCallback*(fn: LibLogFn; userdata: pointer) =
  libSetLogFn(fn, userdata)
```

**GC safety:**

- Don’t pass Nim closures to C as callbacks.
- If you store Nim data for callbacks, ensure it is globally rooted or manually managed.
- Consider `gcsafe` only if the callback never touches GC-managed data.

---

## 9. Memory Ownership, Lifetime, and Safety

**Define ownership clearly:**

* **Owned (Move-Only)**: Use the destructor pattern. The Nim object "owns" the C pointer. Use `ensureMove` to transfer ownership.
* **Borrowed**: C owns memory; caller must not free. Return a raw `ptr` or thin wrapper without a `=destroy` hook.

**When to use `{.error.}` on `=copy`/`=dup` hooks:**

* **No C Copy Mechanism**: Because the C library offers no way to copy the object, the wrapper does not offer it either.
* **Pointer Stability**: To prevent multiple Nim objects from managing the same C pointer, which causes double-free crashes.

Prefer `ensureMove()` (compiler-verified); use `move()` only to force a move.
If you implement a custom `=destroy`, explicitly call `=destroy` for owned nested
destructor-managed fields (`string`, `seq`, etc.) after releasing C resources, or they can leak.

---

## 10. Error Handling Patterns

**C error reporting:**

- Return codes (0 / non-zero)
- `errno`
- Null pointers

**Provide both layers:**

- Raw layer returns the exact codes.
- Ergonomic layer raises exceptions or avoid a `Result`, `Option` types, or "success" boolean tuples for error states.

```nim
proc openDevice*(path: string): Handle =
  result.raw = libOpen(path.cstring)
  if result.raw.isNil:
    raise newException(IOError, "open failed")
```

Keep error behavior predictable and testable.

---

## 11. Testing & Verification Checklist

* **Compile check**: Ensure Nim compiles with library headers.
* **Link check**: Confirm library links (static or dynamic).
- **Smoke test**: call one simple function.
* **ABI checks**: `sizeof`, `alignof`, field offsets.
- **Runtime checks**: verify ownership rules and callback invocation.

**Common failure symptoms:**

- Crashes at call sites → wrong calling convention or struct layout.
- Garbage values → wrong integer width or alignment.
- Random crashes → lifetime issues or freed memory.

---

## 12. Common Pitfalls (Concrete)

- Wrong calling convention (`cdecl` vs `stdcall`).
- Wrong integer widths (`int` vs `long` vs `size_t`).
- Passing Nim `string` directly to C without `.cstring`.
- Struct packing mismatch (missing `packed`, wrong field order).
- Returning pointers to temporary memory or stack buffers.
- Callbacks capturing GC-managed state or closures.
- Using `seq` where C expects stable memory (reallocation risk).
- Lifetime issues with `cstring` (temporary pointer invalid after call).

---

## Example Set (Minimal, Generic)

### A. Strings in/out

C:
```c
const char* LIB_GetName(LIB_Handle* h);
int LIB_SetName(LIB_Handle* h, const char* name);
```

Raw Nim:
```nim
proc libGetName*(h: ptr LibHandle): cstring
  {.importc: "LIB_GetName", cdecl.}
proc libSetName*(h: ptr LibHandle; name: cstring): cint
  {.importc: "LIB_SetName", cdecl.}
```

Ergonomic Nim:
```nim
proc name*(h: Handle): string =
  let p = libGetName(h.raw)
  if p.isNil: return ""
  $p

proc setName*(h: Handle; name: string) =
  if libSetName(h.raw, name.cstring) != 0:
    raise newException(ValueError, "setName failed")
```

### B. Pointer + length buffer

C:
```c
int LIB_Read(LIB_Handle* h, unsigned char* out, size_t len);
```

Raw Nim:
```nim
proc libRead*(h: ptr LibHandle; outBuf: ptr cuchar; len: csize_t): cint
  {.importc: "LIB_Read", cdecl.}
```

Ergonomic Nim:
```nim
proc read*(h: Handle; buf: var openArray[byte]): int =
  if buf.len == 0: return 0
  let rc = libRead(h.raw, cast[ptr cuchar](addr buf[0]), csize_t buf.len)
  int rc
```

### C. Create / destroy resource (Move-Only)

C:

```c
LIB_Handle* LIB_Open(const char* path);
void LIB_Close(LIB_Handle* h);
```

Raw Nim:

```nim
proc libOpen*(path: cstring): ptr LibHandle
  {.importc: "LIB_Open", cdecl.}
proc libClose*(h: ptr LibHandle)
  {.importc: "LIB_Close", cdecl.}
```

Ergonomic Nim:

```nim
type
  Handle* = object
    raw: ptr LibHandle

proc `=destroy`*(h: Handle) =
  if h.raw != nil:
    libClose(h.raw)

proc `=wasMoved`*(h: var Handle) =
  h.raw = nil

proc `=sink`*(dest: var Handle; src: Handle) =
  `=destroy`(dest)
  dest.raw = src.raw

proc `=copy`*(dest: var Handle; src: Handle) {.error.}
proc `=dup`*(src: Handle): Handle {.error.}

proc open*(path: string): Handle =
  result.raw = libOpen(path.cstring)
  if result.raw.isNil:
    raise newException(IOError, "open failed")
```

### D. Reference Counted Resource (Alternative)

If the resource should be copyable (shared ownership), use the RC pattern instead of `.error`:

```nim
type
  Asset* = object
    raw: ptr LibAsset
    rc: ptr int

proc `=destroy`*(a: Asset) =
  if a.raw != nil:
    if a.rc[] == 0:
      libFreeAsset(a.raw)
      dealloc(a.rc)
    else: dec a.rc[]

proc `=copy`*(dest: var Asset; src: Asset) =
  if src.raw != nil: inc src.rc[]
  `=destroy`(dest)
  dest.raw = src.raw
  dest.rc = src.rc

proc `=dup`*(src: Asset): Asset =
  result = src
  if result.raw != nil:
    inc result.rc[]

proc `=sink`*(dest: var Asset; src: Asset) =
  `=destroy`(dest)
  dest.raw = src.raw
  dest.rc = src.rc

proc `=wasMoved`*(a: var Asset) =
  a.raw = nil
  a.rc = nil

proc loadAsset*(path: string): Asset =
  Asset(raw: libLoad(path.cstring), rc: cast[ptr int](alloc0(sizeof(int))))
```

### E. Callback registration

C:
```c
typedef void (*LIB_OnEvent)(void* userdata, int code);
void LIB_SetOnEvent(LIB_OnEvent cb, void* userdata);
```

Raw Nim:
```nim
type
  LibOnEvent* = proc(userdata: pointer; code: cint) {.cdecl.}

proc libSetOnEvent*(cb: LibOnEvent; userdata: pointer)
  {.importc: "LIB_SetOnEvent", cdecl.}
```

Ergonomic Nim:
```nim
proc onEventBridge(userdata: pointer; code: cint) {.cdecl.} =
  discard userdata
  discard code

proc setOnEvent*(cb: LibOnEvent; userdata: pointer) =
  libSetOnEvent(cb, userdata)
```

---

## Quick Do / Don’t

**Do:**

- Keep raw bindings minimal and ABI-faithful.
- Use `cint`, `csize_t`, `cstring` for C interop.
- Provide safe wrappers that validate errors and manage resources.

**Don’t:**

- Pass Nim `string` directly as `char*`.
- Convert pointers in the raw layer.
- Use closures for callbacks unless you fully manage lifetime and GC safety.
