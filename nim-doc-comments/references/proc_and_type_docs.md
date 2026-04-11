Doc placement for procs, types, enums, consts, and fields.

## Proc docs

```nim
proc encodeToken*(value: Token): string =
  ## Encodes `value` as a compact URL-safe token.
  ##
  ## Raises `ValueError` if `value` cannot be represented in the target format.
  discard
```

## Type with inline trailing docs

```nim
type
  Hash* = int ## A hash value.
```

## Type with multi-line docs

```nim
type
  Tree* = object ## Mutable builder used to assemble output.
                 ## Copying shares the payload until mutation detaches it.
    p: ptr TreePayload
```

## Enum docs

```nim
type
  XmlNodeKind* = enum ## Different kinds of XML nodes.
    xnText,           ## A text element.
    xnElement,        ## An element with zero or more children.
    xnComment         ## An XML comment.
```

## Object field docs

```nim
type
  RequestContext* = object ## Parsed request with validated headers and route parameters.
    headers*: HttpHeaders ## Request headers.
    routeParams*: Table[string, string] ## Decoded route parameters.
```

## Const docs

```nim
const
  HeaderLimit* = 10_000 ## Maximum accepted header bytes.
  DefaultPort* = 443    ## Default HTTPS port for outbound requests.
```

### Key points

- Proc docs go after the signature, before the body.
- In `type`/`const` blocks, use inline trailing `##` on the declaration line.
- Multi-line docs use continuation `##` lines aligned under the declaration.
- Only exported symbols (`*`) appear in rendered output.
