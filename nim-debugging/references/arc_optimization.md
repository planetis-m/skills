Use `--expandArc` to explain an ownership operation, then apply `move` only
when the source is intentionally at last use.

```nim
type
  Container = object
    items: seq[string]

proc takeFirstCopy(container: var Container): string =
  result = container.items[0]
  container.items.delete 0

proc takeFirstMove(container: var Container): string =
  result = move(container.items[0])
  container.items.delete 0

var copied = Container(items: @["alpha", "beta"])
doAssert copied.takeFirstCopy() == "alpha"
doAssert copied.items == @["beta"]

var moved = Container(items: @["gamma", "delta"])
doAssert moved.takeFirstMove() == "gamma"
doAssert moved.items == @["delta"]
```

Inspect both reachable procedures:

```bash
nim c --expandArc:takeFirstCopy --expandArc:takeFirstMove example.nim
```

Look for an injected `=copy` in `takeFirstCopy` and `move` in
`takeFirstMove`. Exact expansion text can change with compiler versions and
surrounding code, so compare ownership operations rather than matching a whole
listing.

## Key points

- `move` is destructive: use it only when the source value is intentionally
  discarded or reinitialized.
- Keep the operation under test reachable from the program entry point.
- Inspect under the memory manager used by the target project.
- Removing a visible copy is an optimization hypothesis, not proof of a
  meaningful speedup. Measure when performance matters.
- Re-run behavior tests after changing ownership operations.
