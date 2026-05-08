# Structure-aware fuzzing: float array sum

Demonstrates `customMutator` and `customCrossOver` for a typed-data fuzz
target. The target computes a sum of floats and checks for NaN results.

## Source: `experiments/fpsum.nim` (simplified)

```nim
import std/[random, fenv, math]

proc sum(x: openArray[float]): float =
  result = 0.0
  for b in items(x):
    result = if isNaN(b): result else: result + b

proc quitOrDebug() {.noreturn, importc: "abort", header: "<stdlib.h>", nodecl.}

proc testOneInput(data: ptr UncheckedArray[byte], len: int): cint {.
    exportc: "LLVMFuzzerTestOneInput", raises: [].} =
  result = 0
  let cLen = len div sizeof(float)
  if cLen == 0: return
  var copy = newSeq[float](cLen)
  copyMem(addr copy[0], data, copy.len * sizeof(float))
  let res = sum(copy)
  if isNaN(res):
    quitOrDebug()

proc initialize(): cint {.exportc: "LLVMFuzzerInitialize".} =
  {.emit: "N_CDECL(void, NimMain)(void); NimMain();".}
```

## Custom mutator

Operates at the float level instead of raw bytes. Mutations: change one
element, add element, delete element, or shuffle. Uses the seed for
determinism.

```nim
proc randFloat(gen: var Rand): float =
  case gen.rand(10)
  of 0: result = NaN
  of 1: result = minimumPositiveValue(float)
  of 2: result = maximumPositiveValue(float)
  of 3: result = -minimumPositiveValue(float)
  of 4: result = -maximumPositiveValue(float)
  of 5: result = epsilon(float)
  of 6: result = -epsilon(float)
  of 7: result = Inf
  of 8: result = -Inf
  of 9: result = 0.0
  else: result = gen.rand(-1.0..1.0)

proc customMutator(data: ptr UncheckedArray[byte], len, maxLen: int,
    seed: int64): int {.exportc: "LLVMFuzzerCustomMutator", raises: [].} =
  let cLen = len div sizeof(float)
  if cLen == 0:
    var tmp = @[1.0, 3.0, 3.0, 7.0]
    result = tmp.len * sizeof(float)
    copyMem(data, addr tmp[0], result)
    return
  var copy = newSeq[float](cLen)
  copyMem(addr copy[0], data, copy.len * sizeof(float))
  var gen = initRand(seed)
  case gen.rand(3)
  of 0: # Change element
    if copy.len > 0:
      copy[gen.rand(0..<copy.len)] = randFloat(gen)
  of 1: # Add element
    copy.add randFloat(gen)
  of 2: # Delete element
    if copy.len > 0: discard copy.pop
  else: # Shuffle elements
    gen.shuffle(copy)
  result = copy.len * sizeof(float)
  if result <= maxLen:
    copyMem(data, addr copy[0], result)
  else:
    result = 0
```

## Custom crossover

Combines two float arrays element-by-element, randomly picking from parent A
or B:

```nim
proc customCrossOver(data1: ptr UncheckedArray[byte], len1: int,
    data2: ptr UncheckedArray[byte], len2: int,
    res: ptr UncheckedArray[byte], maxResLen: int,
    seed: int64): int {.exportc: "LLVMFuzzerCustomCrossOver", raises: [].} =
  let cLen1 = len1 div sizeof(float)
  if cLen1 == 0: return
  var copy1 = newSeq[float](cLen1)
  copyMem(addr copy1[0], data1, copy1.len * sizeof(float))
  let cLen2 = len2 div sizeof(float)
  if cLen2 == 0: return
  var copy2 = newSeq[float](cLen2)
  copyMem(addr copy2[0], data2, copy2.len * sizeof(float))
  let len = min(copy1.len, min(copy2.len, maxResLen div sizeof(float)))
  if len == 0: return
  var buf = newSeq[float](len)
  var gen = initRand(seed)
  for i in 0 ..< buf.len:
    buf[i] = if gen.rand(1.0) <= 0.5: copy1[i] else: copy2[i]
  result = buf.len * sizeof(float)
  assert result <= maxResLen
  copyMem(res, addr buf[0], result)
```

## Key patterns

- **Parse → mutate → serialize**: Read typed data from byte buffer, apply
  mutations at the type level, write back to byte buffer.
- **Boundary values**: The `randFloat` generator includes special values
  (NaN, Inf, min/max, epsilon) that raw byte mutation would rarely produce.
- **Length tracking**: Always check `result <= maxLen`. Return 0 or
  original `len` on overflow.
- **Seed determinism**: Same `seed` → same mutation. Required by libFuzzer
  for reproducibility.
- **Empty input handling**: If `cLen == 0`, the mutator injects a valid
  dummy array instead of failing.

## When to use this pattern

Use when the input has a known element type and mutations at that level find
bugs faster than raw bytes. Skip when libFuzzer's built-in mutators already
achieve good coverage.
