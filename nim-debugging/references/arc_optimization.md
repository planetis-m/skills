Use `--expandArc` to find a copy when ownership should transfer.

This example transfers tuple elements between arrays. Each tuple contains a
`string` and a `seq[byte]`, so its copy hook is lifted from both fields.

```nim
type
  FileEntry = tuple[
    path: string,
    data: seq[byte]]

  FileEntries = array[3, FileEntry]

proc drainByCopy(source: var FileEntries; dest: var FileEntries) =
  for i in 0..high(dest):
    dest[i] = source[i]
    source[i] = default(FileEntry)

proc drainByMove(source: var FileEntries; dest: var FileEntries) =
  for i in 0..high(dest):
    dest[i] = move(source[i])

proc sampleEntries(): FileEntries =
  result = [
    (path: "one.txt", data: @[1'u8, 2]),
    (path: "two.txt", data: @[3'u8, 4]),
    (path: "three.txt", data: @[5'u8, 6])]

proc main =
  var copySource = sampleEntries()
  var copied: FileEntries
  copySource.drainByCopy(copied)
  doAssert copied == sampleEntries()
  doAssert copySource == default(FileEntries)

  var moveSource = sampleEntries()
  var moved: FileEntries
  moveSource.drainByMove(moved)
  doAssert moved == copied
  doAssert moveSource == default(FileEntries)

main()
```

Inspect both reachable procedures:

```bash
nim c --expandArc:drainByCopy --expandArc:drainByMove example.nim
```

`drainByCopy` contains `=copy` followed by clearing the source. `drainByMove`
contains `=sink(dest[i], move(source[i]))`; moving already leaves the source
element in its default state.

Use `move` only when the operation transfers ownership and the source element
must not retain its value. Re-run the behavior checks under the project's
memory manager, then measure before treating the removed copy as a useful
optimization.
