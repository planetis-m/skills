Use the complete ASan recipe for Nim-managed unsafe allocation and a normal
debug build with Valgrind for an independent leak check.

```nim
import std/os

proc cMalloc(size: csize_t): pointer
    {.importc: "malloc", header: "<stdlib.h>".}

proc overflow() =
  let memory = alloc(4 * sizeof(int))
  let values = cast[ptr UncheckedArray[int]](memory)
  values[0] = 10
  values[4] = 50
  dealloc(memory)

proc signalFault() =
  let invalid = cast[ptr int](1)
  echo invalid[]

proc leak() =
  let memory = cMalloc(64)
  cast[ptr int](memory)[] = 42

if paramCount() == 0:
  echo "choose overflow, signal, or leak"
else:
  case paramStr(1)
  of "overflow":
    overflow()
  of "signal":
    signalFault()
  of "leak":
    leak()
  else:
    raise newException(ValueError, "expected overflow, signal, or leak")
```

Compile for AddressSanitizer:

```bash
nim c \
  --passC:"-fsanitize=address -fno-omit-frame-pointer" \
  --passL:"-fsanitize=address -fno-omit-frame-pointer" \
  -g \
  -d:useMalloc \
  -d:noSignalHandler \
  -o:asan_example \
  example.nim
./asan_example overflow
./asan_example signal
```

Both `--passC` and `--passL` are required. `-d:useMalloc` exposes allocations
made through Nim's `alloc` to ASan. `-d:noSignalHandler` lets ASan report signal
faults instead of Nim's signal handler intercepting them.

For Valgrind:

```bash
nim c -g -o:valgrind_example example.nim
valgrind --leak-check=full --error-exitcode=1 ./valgrind_example leak
```

## Key points

- Preserve the target project's memory manager when reproducing the defect.
- GCC reports symbolized Nim locations with `-g`. Clang also requires
  `llvm-symbolizer` in `PATH`.
- The ASan and Valgrind commands are Linux-oriented; verify toolchain-specific
  flags before adapting them to another platform.
- A sanitizer report identifies the invalid access site and allocation site;
  trace ownership and bounds from those two points.
- Re-run the original failing input after fixing the defect.
