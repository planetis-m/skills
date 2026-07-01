# Generated Symbols

A complete template plugin that binds an argument to a fresh local before
using it.

```nim
# echofresh.nim
template echoFresh*(value: untyped) {.plugin: "echofreshplug".}
```

```nim
# echofreshplug.nim
import plugins

proc transform(root: NifCursor): NifBuilder =
  var value = callArgs(root)
  let info = value.info
  let local = genSym()
  result = createTree()
  result.withTree StmtsS, root.info:
    result.withTree LetS, info:
      result.addSymDef local, info
      result.addEmptyNode3(info)
      result.takeTree value
    result.withTree CallS, root.info:
      result.addIdent "echo"
      result.addSymUse local, info

let input = loadPluginInput()
saveTree transform(input)
```

```nim
# app.nim
import std / syncio
import echofresh

proc main() =
  let tmp = "outer"
  echoFresh "first"
  echoFresh "second"
  echo tmp

main()
```

## Key points

- Call `genSym()` once for each generated local.
- Emit that `SymId` with `addSymDef`, then reuse it with `addSymUse`.
- Reusing the generated `SymId` connects the definition to each use without a
  textual local name.

## When to use

Use `genSym` whenever generated code needs a local definition that must not
collide with caller or plugin-generated names.
