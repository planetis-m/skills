Diagnose an unwanted ownership copy when a `var`-parameter field is passed to a `sink` parameter, confirm it with `--expandArc`, and fix it with `move()`.

```nim
type
  Shard = object
    data: string
  Created = object
    remote: Shard

var copies = 0

proc `=copy`(dst: var Shard; src: Shard) =
  inc copies
  dst.data = src.data

proc consume(x: sink Shard) =
  discard x.data

# Copy: field of a var parameter — auto-sink does not fire.
proc takeRemote(c: var Created) =
  consume(c.remote)

# Fix: explicit move eliminates the copy.
proc takeRemoteMove(c: var Created) =
  consume(move(c.remote))

proc main =
  copies = 0
  var c = Created(remote: Shard(data: "payload"))
  takeRemote(c)
  echo "takeRemote copies: ", copies

  copies = 0
  var c2 = Created(remote: Shard(data: "payload"))
  takeRemoteMove(c2)
  echo "takeRemoteMove copies: ", copies

main()
```

Run the copy counter, then inspect both procs with `--expandArc`:

```bash
nim c -r example.nim
nim c --expandArc:takeRemote --expandArc:takeRemoteMove example.nim
```

`takeRemote` prints `1`; its expansion shows a `=dup` copy before the call:

```
:tmpD = =dup(c.remote)
consume(:tmpD)
```

`takeRemoteMove` prints `0`; its expansion shows the move with no copy:

```
consume(move(c.remote))
```

## Key points

- Measure inside a named proc. Last-use auto-sink fires for locals and their
  fields inside procs but never at module top level, so top-level counting
  misreports every case as a copy.
- Auto-sink does not fire for fields of `var` parameters or loop-indexed
  elements. `move()` eliminates the copy for exactly these cases.
- `ensureMove(c.remote)` is a compile error here — the compiler cannot prove a
  var-parameter field is last use. Use `move()`, not `ensureMove()`.
- `move()` calls `=wasMoved` on the source and leaves it moved-from; the source's
  `=destroy` still runs at scope exit. `--expandArc` shows the `=destroy`.
- The same copy appears under `--mm:orc` (default), `--mm:arc`, and
  `--mm:atomicArc`.
- See `nim-ownership-hooks` for `move` vs `ensureMove` semantics; see
  `nim-api-design` for caller-facing auto-sink rules.
