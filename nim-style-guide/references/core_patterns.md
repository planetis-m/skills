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

func formatNote(number: int; title, details: string): string =
  result = $number & "."
  if title.len > 0:
    result.add " " & title
  if details.len > 0:
    result.add " — " & details

proc renderNotes(notes: openArray[ReleaseNote];
    options = RenderOptions()): seq[string] =
  result.add options.heading
  for i, note in notes:
    let title = note.title.strip
    if title.len > 0 or options.includeUntitled:
      result.add formatNote(i + 1, title,
        details = note.details.strip)

let notes = [
  ReleaseNote(title: " Added Search ", details: "new index"),
  ReleaseNote(title: "", details: "internal"),
  ReleaseNote(title: "Fixed Cache", details: "")
]

doAssert notes.find("Fixed Cache") == 2
doAssert notes.find("removed") == -1

doAssert renderNotes(notes) == @[
  "Changes",
  "1. Added Search — new index",
  "3. Fixed Cache"
]

let allNotes = renderNotes(notes,
  RenderOptions(heading: "All changes", includeUntitled: true))
doAssert allNotes == @[
  "All changes",
  "1. Added Search — new index",
  "2. — internal",
  "3. Fixed Cache"
]
```
