Identifying and fixing an unnecessary copy using `--expandArc`

This example demonstrates how to use `--expandArc` to detect a copy where a move would suffice, and how to fix it.

## Unoptimized version (with copy)

```nim
type
  Container = object
    items: seq[string]

proc newContainer(items: seq[string]): Container =
  result = Container(items: items)

proc takeFirst(c: var Container): string =
  result = c.items[0]
  c.items.delete(0)
```

Compile and inspect:

```
nim c --expandArc:takeFirst test.nim
```

Output:

```
--expandArc: takeFirst

`=copy`(result, c.items[0])
delete(c.items, 0)
-- end of expandArc ------------------------
```

The `=copy` call copies the string at `c.items[0]` into `result`. Since the element is about to be deleted from the sequence, this copy is wasteful.

## Optimized version (with move)

```nim
proc takeFirstMove(c: var Container): string =
  result = move(c.items[0])
  c.items.delete(0)
```

Compile and inspect:

```
nim c --expandArc:takeFirstMove test.nim
```

Output:

```
--expandArc: takeFirstMove

result = move(c.items[0])
delete(c.items, 0)
-- end of expandArc ------------------------
```

The `=copy` is replaced with a direct `move`. No reference count increment or string copy occurs. The ownership of the string's data buffer transfers directly to `result`.

## Key points

- `--expandArc:<proc>` shows the compiler's injected ownership operations (copy, move, destroy, sink).
- The target proc must be reachable from the program entry point. Uncalled procs are skipped by the analysis.
- Look for `=copy` where the source is about to be discarded — those are optimization opportunities.
- Replace the assignment with `move()` to eliminate the copy.
- `--expandArc` works under `--mm:orc`, `--mm:arc`, and `--mm:atomicArc`. Test under the same mode your project uses.
- The `--expandArc` flag also shows `=destroy` calls in `finally` blocks, which is useful for verifying cleanup order.
