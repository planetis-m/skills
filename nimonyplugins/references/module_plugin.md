# Module Plugin

A complete module plugin that removes `discard` statements while preserving
the rest of the semantically checked module.

```nim
# stripdiscards.nim
import plugins

proc rewrite(r: var Replacer) =
  if r.isAtom:
    keep r, Any
  elif r.stmtKind == DiscardS:
    drop r, DiscardS
  else:
    loopKeepTag r:
      rewrite r

var r = loadReplacer()
rewrite r
saveReplacer r
```

```nim
# app.nim
{.plugin: "stripdiscards".}

import std / syncio

proc sideEffect(): int =
  echo "this call is removed"
  1

discard sideEffect()
echo "MODULE: PASS"
```

## Key points

- `loadReplacer` starts at the full module root.
- A recursive `loopKeepTag` pass preserves every subtree except the one
  explicitly dropped.
- Module-plugin output is not semantically checked again, so preserving typed
  subtrees is the safe default.

## When to use

Use a module plugin for whole-module analysis or transformations over already
typed code.
