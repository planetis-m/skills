Wrap each variant branch's payload in its own named object type when branches
need fields with the same name.

```nim
type
  EntryKind* = enum
    File
    Dir
    Device

  EntryFile* = object
    name: string
    modified: float64
    size: int64

  EntryDir* = object
    name: string
    modified: float64

  EntryDevice* = object
    name: string

  Entry* = ref object
    case kind: EntryKind
    of File:
      file: EntryFile
    of Dir:
      dir: EntryDir
    of Device:
      device: EntryDevice

proc describe*(e: Entry): string =
  case e.kind
  of File:
    e.file.name & " (" & $e.file.size & " bytes)"
  of Dir:
    e.dir.name & "/"
  of Device:
    e.device.name
```

## Key points

- A branch field also cannot reuse the name of a field declared before the
  `case` selector.
- Wrap payloads only when branches need the same attribute name; branches with
  distinct field names can declare fields directly in the variant.
