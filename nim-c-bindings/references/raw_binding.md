A complete raw mapping for a C API with an opaque handle and a value struct.

```c
/* counter.h */
#ifndef COUNTER_H
#define COUNTER_H

#include <stddef.h>

typedef struct counter counter;

typedef struct {
  int bias;
  size_t capacity;
} counter_config;

counter *counter_open(counter_config config);
void counter_close(counter *handle);
int counter_push(counter *handle, const int *values, size_t len);

#endif
```

```nim
const counterHeader = "counter.h"

type
  CounterObj {.
      importc: "counter", header: counterHeader, incompleteStruct.} = object
  Counter* = ptr CounterObj

  CounterConfig* {.
      importc: "counter_config", header: counterHeader, bycopy.} = object
    bias*: cint
    capacity*: csize_t

{.push cdecl, header: counterHeader.}

proc counterOpen*(config: CounterConfig): Counter
  {.importc: "counter_open".}
proc counterClose*(handle: Counter)
  {.importc: "counter_close".}
proc counterPush*(handle: Counter; values: ptr cint; len: csize_t): cint
  {.importc: "counter_push".}

{.pop.}
```

Configure the header search path and library input in the consuming project.
The raw module deliberately retains the pointer-plus-length interface and does
not manage the handle lifetime.

## Key points

- The incomplete C type is used only behind a pointer.
- The by-value struct preserves the C field order and C-compatible types.
- Nim names may be idiomatic while `importc` preserves the exact C symbols.
- Linking and runtime packaging remain project decisions.
