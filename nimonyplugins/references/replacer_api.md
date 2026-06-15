# Replacer API

Read this when a plugin keeps most of the input tree but edits selected nodes. `Replacer` carries both the source cursor and destination builder, so operations advance input and output together.

## Operations

- `keep r, Kind`: copy one child and advance.
- `drop r, Kind`: skip one child.
- `replace r, Kind, replacement`: skip one child and emit a `NifCursor` or `NifBuilder`.
- `keepTag r:`: copy the current node tag, rewrite its children, then close it.
- `loopKeepTag r:`: `keepTag` plus `while ...hasMore` for all children.
- `replaceHead r, NewTag, info:`: enter the current node but emit a different tag.
- `peek r:`: analyze ahead and restore the cursor. Do not emit inside `peek`.
- `getCursor(r)` / `setCursor(r, c)`: save and restore cursor position.
- `r.dest`: direct access to the output builder for synthetic children.

Always pass an expected kind: `Any`, `Expr`, `Type`, `Stmt`, `Def`, `Sym`, `Dot`, `Lit`, `Nested`, or a concrete tag such as `CallX`, `CallS`, `AsgnS`, or `ObjectT`.

## Pattern Map

```nim
if r.isAtom:
  keep r, Any
elif isCallTo(getCursor(r), "internalOnly"):
  drop r, CallX
elif isCallTo(getCursor(r), "pii"):
  replace r, CallX, replacementTree()
else:
  loopKeepTag r:
    transform r
```

Use raw `NifCursor` copies for classification:

```nim
proc firstStringArg(n: NifCursor): string =
  if n.kind != ParLe:
    return ""
  var child = firstChild(n)
  if child.hasMore:
    skip child
  if child.hasMore and child.kind == StringLit:
    result = child.stringValue
```

Use `peek` only for read-ahead:

```nim
proc isEmptyTag(r: var Replacer): bool =
  var found = false
  peek r:
    let c = getCursor(r)
    if isCallTo(c, "tag"):
      found = firstStringArg(c) == ""
  result = found
```

Save and restore the source cursor when a transform needs to attempt one path and then retry from the same input position:

```nim
let saved = getCursor(r)
if not trySpecialRewrite(r):
  setCursor(r, saved)
  keep r, Any
```

## End-To-End: Privacy Audit Event

This plugin-backed varargs template turns a convenient event call into a normalized audit sink call. It redacts PII, removes internal-only data, drops empty tags, preserves normal helper calls, and appends a policy stamp.

```nim
# auditapi.nim
var auditTrail* = ""

proc user*(id: string): string =
  "user:" & id

proc tag*(value: string): string =
  "tag:" & value

proc pii*(value: string): string =
  value

proc internalOnly*(value: string): string =
  value

proc auditCommit*(event, account, detail, label, policy: string) =
  auditTrail.add event
  auditTrail.add "|"
  auditTrail.add account
  auditTrail.add "|"
  auditTrail.add detail
  auditTrail.add "|"
  auditTrail.add label
  auditTrail.add "|"
  auditTrail.add policy
  auditTrail.add "\n"

template auditEvent*() {.varargs, plugin: "auditplug".}
```

```nim
# auditplug.nim
import plugins
import std/strutils

const PolicyStamp = "policy:privacy-audit-v2"

proc callHeadMatches(n: NifCursor; name: string): bool =
  case n.kind
  of Ident:
    result = n.identText == name
  of Symbol:
    let text = n.symText
    result = text == name or text.startsWith(name & ".") or
        text.endsWith("." & name)
  else:
    result = false

proc isCallTo(n: NifCursor; name: string): bool =
  if n.kind != ParLe or n.exprKind != CallX:
    return false
  var child = firstChild(n)
  result = callHeadMatches(child, name)

proc firstStringArg(n: NifCursor): string =
  if n.kind != ParLe:
    return ""
  var child = firstChild(n)
  if child.hasMore:
    skip child
  if child.hasMore and child.kind == StringLit:
    result = child.stringValue

proc isEmptyTag(r: var Replacer): bool =
  var found = false
  peek r:
    let c = getCursor(r)
    if isCallTo(c, "tag"):
      found = firstStringArg(c) == ""
  result = found

proc redacted(info: LineInfo): NifBuilder =
  result = createTree()
  result.addStrLit "[redacted]"

proc rewriteArg(r: var Replacer) =
  if r.isAtom:
    keep r, Any
  elif isCallTo(getCursor(r), "pii"):
    replace r, CallX, redacted(r.info)
  elif isCallTo(getCursor(r), "internalOnly"):
    drop r, CallX
  elif isEmptyTag(r):
    drop r, CallX
  else:
    loopKeepTag r:
      rewriteArg r

var r = loadReplacer()
replaceHead r, CallS, r.info:
  r.dest.addIdent "auditCommit"
  while getCursor(r).hasMore:
    rewriteArg r
  r.dest.addStrLit PolicyStamp
saveReplacer(r)
```

```nim
# app.nim
import std/syncio
import auditapi

auditEvent("payment", user("acct:42"), pii("card:4111"), tag("pci"),
  internalOnly("trace-99"), tag(""))

echo auditTrail
```

Expected output:

```text
payment|user:acct:42|[redacted]|tag:pci|policy:privacy-audit-v2
```

Notes:
- Marker helpers like `pii` and `internalOnly` are declared so arguments resolve before the plugin output is rechecked.
- Symbol heads may be qualified after semantic analysis, so match both identifiers and symbol names.
- Recursive `loopKeepTag` preserves ordinary calls such as `user(...)` and `tag("pci")`.
- `drop` removes whole marker calls. `replace` swaps a marker call for a literal. `r.dest.addStrLit` appends the policy argument.
