A release-note renderer showing the guide's default formatting,
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

func find(notes: openArray[ReleaseNote]; title: string): int =
  result = -1
  for i, note in notes:
    if note.title == title:
      return i

func formatNote(n: int; title, details: string): string =
  result = $n & "."
  if title.len > 0:
    result.add " " & title
  if details.len > 0:
    result.add " — " & details

proc makeOptions(heading = ""; includeUntitled = false): RenderOptions =
  result = RenderOptions()
  if heading.len > 0:
    result.heading = heading
  result.includeUntitled = includeUntitled

proc renderNotes(notes: openArray[ReleaseNote];
    opts = RenderOptions()): seq[string] =
  result.add opts.heading
  for i, note in notes:
    let title = note.title.strip
    if title.len > 0 or opts.includeUntitled:
      result.add formatNote(i + 1, title,
        details = note.details.strip)
```

## Key points

- `makeOptions` initializes `result = RenderOptions()` before assigning
  fields, so the declared default `heading: string = "Changes"` is applied.
  Without that line, `result.heading` would be `""`, not `"Changes"`.
- Omitted fields in object constructors use their declared defaults, so
  `RenderOptions(includeUntitled: true)` keeps `heading = "Changes"`.
