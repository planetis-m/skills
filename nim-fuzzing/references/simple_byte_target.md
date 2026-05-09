# Simple byte fuzz target

Minimum working example. The target searches for the byte sequence `FUZZ`
with an off-by-one bug in the bounds check (4 bytes checked against a
length-3 guard).

## Source: `tests/tfuzz.nim`

```nim
proc fuzzMe(data: openarray[byte]): bool =
  result = data.len >= 3 and
    data[0].char == 'F' and
    data[1].char == 'U' and
    data[2].char == 'Z' and
    data[3].char == 'Z' # <-- bug: reads index 3 when only 3 bytes guaranteed

proc initialize(): cint {.exportc: "LLVMFuzzerInitialize".} =
  {.emit: "N_CDECL(void, NimMain)(void); NimMain();".}

proc testOneInput(data: ptr UncheckedArray[byte], len: int): cint {.
    exportc: "LLVMFuzzerTestOneInput", raises: [].} =
  result = 0
  discard fuzzMe(data.toOpenArray(0, len-1))
```

## Build config: `tfuzz.nims`

```nim
--cc: clang
--panics: on
--define: noSignalHandler
--define: useMalloc
--noMain: on
--passC: "-fsanitize=fuzzer,address,undefined"
--passL: "-fsanitize=fuzzer,address,undefined"
--debugger: native
```

## Run

```bash
mkdir corpus
echo -n "FUZ" > corpus/seed_01
./tfuzz corpus/
```

The fuzzer discovers the out-of-bounds read — `data[3]` when `len == 3`.
Sanitizer produces a heap-buffer-overflow report.

## What this demonstrates

- The two required procs (`initialize`, `testOneInput`)
- `toOpenArray` for raw byte access
- `raises: []` on the test function
- `result = 0` return convention
- A seed corpus with a well-formed input just below the bug threshold
