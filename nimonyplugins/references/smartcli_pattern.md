# Smartcli Pattern

`smartcli` is a real plugin-backed DSL, not a toy example.

Public API:

```nim
template cliapp*(spec: string): untyped {.plugin: "smartcliplugin".}
```

Plugin entrypoint:

```nim
let root = loadPluginInput()
let specNode = extractSpecNode(root)
if specNode.kind == StringLit:
  let rawSpec = specNode.stringValue
  let spec = parseSpec(rawSpec)
  saveTree generate(rawSpec, spec, root.info)
else:
  saveTree errorTree("cliapp expects a string literal", specNode)
```

Generation shape:

```nim
proc generate(rawSpec: string; spec: CliSpec; info: LineInfo): Tree =
  result = createTree()
  result.withTree StmtsS, info:
    result.withTree BlockS, info:
      result.addEmptyNode()
      result.withTree StmtsS, info:
        emitOptionsDecl result, spec
        emitParseProc result, rawSpec, spec
        result.withTree CallX, NoLineInfo:
          result.addIdent("parseCli")
```

Key points
- Keep runtime helpers in the public module.
- Keep NIF traversal and tree generation in the plugin module.
- Parse the DSL into ordinary Nim objects first if that makes generation simpler.
- Emit full generated code as a `Tree`. Do not rebuild the input token by token unless that is the goal.
