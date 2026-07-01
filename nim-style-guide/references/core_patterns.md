A complete release-note renderer showing the guide's default formatting,
callable, local-variable, control-flow, and constructor choices.

```nim
import std/strutils

type
  ReleaseNote = object
    title: string
    details: string

  RenderOptions = object
    heading: string = "Changes"
    includeUntitled: bool

func normalizedTitle(title: string): string =
  title.strip.toLowerAscii

func formatNote(number: int; title, details: string): string =
  result = $number & ". " & title
  if details.len > 0:
    result.add " — " & details

proc renderNotes(notes: openArray[ReleaseNote];
    options = RenderOptions()): seq[string] =
  result.add options.heading
  for idx in 0..<notes.len:
    let note = notes[idx]
    let title = normalizedTitle(note.title)
    if title.len > 0 or options.includeUntitled:
      result.add formatNote(idx + 1, title,
        details = note.details.strip)

let notes = [
  ReleaseNote(title: " Added Search ", details: "new index"),
  ReleaseNote(title: "", details: "internal"),
  ReleaseNote(title: "Fixed Cache", details: "")
]

doAssert renderNotes(notes) == @[
  "Changes",
  "1. added search — new index",
  "3. fixed cache"
]

let allNotes = renderNotes(notes,
  RenderOptions(heading: "All changes", includeUntitled: true))
doAssert allNotes == @[
  "All changes",
  "1. added search — new index",
  "2.  — internal",
  "3. fixed cache"
]
```

## Key points

- Imports use the `std/` prefix and identifiers follow ordinary Nim casing.
- Pure transformations are `func`; the accumulating operation is a `proc`.
- Stable locals use `let`, while the implicit `result` carries mutable output.
- The loop keeps its normal path structured without `continue`.
- Range operators are compact and wrapped calls use continued indentation.
- The default constructor omits fields whose declaration defaults should
  apply.
