# Protocol fuzzer: HTTP request parser

Harness excerpt for fuzzing an HTTP request parser. Demonstrates string
extraction, error triage, and seed selection.

## Source: `harness/asynchttpserver_fuzzer.nim` (annotated)

```nim
import std/[httpcore, parseutils, strutils, uri]

const
  localMaxBody = 8 * 1024 * 1024
  localMaxLine = 8 * 1024

type ParsedRequest = object
  reqMethod: HttpMethod
  headers: HttpHeaders
  protocol: tuple[orig: string, major, minor: int]
  url: Uri
  body: string

# --- Code under test (simplified parser) ---

proc parseProtocolOriginal(protocol: string): tuple[orig: string, major, minor: int] =
  result = default(tuple[orig: string, major, minor: int])
  var i = protocol.skipIgnoreCase("HTTP/")
  if i != 5:
    raise newException(ValueError, "Invalid request protocol. Got: " & protocol)
  result.orig = protocol
  i.inc protocol.parseSaturatedNatural(result.major, i)
  i.inc
  i.inc protocol.parseSaturatedNatural(result.minor, i)

proc parseMethod(part: string): HttpMethod =
  case part
  of "GET": HttpGet
  of "POST": HttpPost
  of "HEAD": HttpHead
  of "PUT": HttpPut
  of "DELETE": HttpDelete
  of "PATCH": HttpPatch
  of "OPTIONS": HttpOptions
  of "CONNECT": HttpConnect
  of "TRACE": HttpTrace
  else:
    raise newException(ValueError, "unknown method")

proc nextLine(input: string, pos: var int): string =
  result = ""
  if pos < input.len:
    let start = pos
    while pos < input.len and input[pos] notin {'\r', '\n'}:
      inc pos
    result = input[start ..< pos]
    if pos < input.len and input[pos] == '\r': inc pos
    if pos < input.len and input[pos] == '\n': inc pos

# ... (parseFullRequestOriginal omitted for brevity, see full source) ...

# --- Harness ---

proc testOneInput(data: ptr UncheckedArray[byte], len: int): cint {.
    cdecl, exportc: "LLVMFuzzerTestOneInput", raises: [].} =
  result = 0
  if len > 0:
    var input = newString(len)
    copyMem(addr input[0], data, len)
    try:
      discard parseFullRequestOriginal(input)
    except ValueError:
      discard          # Valid rejection: malformed HTTP
  # With --panics:on, Defects auto-crash the process — no catch needed

proc initialize(): cint {.cdecl, exportc: "LLVMFuzzerInitialize".} =
  {.emit: "N_CDECL(void, NimMain)(void); NimMain();".}
```

## Error triage in the harness

With `--panics:on`, `Defect` subtypes crash the process immediately. Only
catch expected error types:

| Catch block     | What it catches | Action |
|-----------------|-----------------|--------|
| `except ValueError` | Malformed HTTP (expected) | `discard` — not a finding |
| (no catch)      | `IndexDefect`, `OverflowDefect` | Auto-crash — confirmed bug |

This prevents the fuzzer from stopping on every malformed input while
automatically flagging real bugs.

## Seed corpus

Minimal valid HTTP requests:

**`corpus/seed_get_http11`**:
```
GET / HTTP/1.1\r\nHost: localhost\r\n\r\n
```

**`corpus/seed_post_content_length`**:
```
POST /submit HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\n\r\nhello
```

**`corpus/seed_post_chunked`**:
```
POST /data HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n
```

Seeds exercise GET, POST with Content-Length, and POST with chunked encoding
— the three main code paths.

## Build and run

```bash
nim c --cc:clang --panics:on -d:noSignalHandler -d:useMalloc --noMain:on \
  --passC:"-fsanitize=fuzzer,address,undefined" \
  --passL:"-fsanitize=fuzzer,address,undefined" \
  -g asynchttpserver_fuzzer.nim

./asynchttpserver_fuzzer -fork=4 -max_len=65536 corpus/
```

## Key patterns

- **String extraction**: `newString` + `copyMem` converts fuzzer bytes to Nim string.
- **Error triage**: Catch only expected parse errors (`ValueError`); let Defects crash the process.
- **Seeds for code paths**: Each seed exercises a different branch of the
  parser (GET, Content-Length POST, chunked POST).
- **Size limits**: `localMaxBody` and `localMaxLine` in the code under test
  prevent memory exhaustion from large fuzzer inputs.
