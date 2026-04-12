# One Coherent Container Surface

Complete example showing a small container API with one constructor path,
direct accessors, and no secondary status-tuple API.

```nim
type
  PackageId = distinct string

  PackageMeta = object
    title: string
    version: string
    tags: seq[string]
    downloads: Natural

  PackageCatalog = object
    ids: seq[PackageId]
    entries: seq[PackageMeta]

proc `==`(a, b: PackageId): bool {.borrow.}
proc `$`(id: PackageId): string {.borrow.}

proc raiseMissingPackage(id: PackageId) {.noinline, noreturn.} =
  raise newException(KeyError, "unknown package: " & $id)

proc initPackageCatalog(initialSize = 8): PackageCatalog =
  PackageCatalog(
    ids: newSeqOfCap[PackageId](initialSize),
    entries: newSeqOfCap[PackageMeta](initialSize)
  )

proc toPackageCatalog(pairs: openArray[(PackageId, PackageMeta)]): PackageCatalog =
  result = initPackageCatalog(pairs.len)
  for (id, meta) in pairs:
    result.ids.add id
    result.entries.add meta

proc findIndex(catalog: PackageCatalog; id: PackageId): int {.inline.} =
  for i, existing in catalog.ids:
    if existing == id:
      return i
  raiseMissingPackage(id)

proc len(catalog: PackageCatalog): int {.inline.} =
  catalog.ids.len

proc meta(catalog: PackageCatalog; id: PackageId): lent PackageMeta {.inline.} =
  result = catalog.entries[findIndex(catalog, id)]

proc tags(catalog: PackageCatalog; id: PackageId): lent seq[string] {.inline.} =
  result = catalog.entries[findIndex(catalog, id)].tags

proc tags(catalog: var PackageCatalog; id: PackageId): var seq[string] {.inline.} =
  result = catalog.entries[findIndex(catalog, id)].tags

proc downloads(catalog: PackageCatalog; id: PackageId): Natural {.inline.} =
  catalog.entries[findIndex(catalog, id)].downloads
```

## Key points

- One primary public representation: `PackageCatalog`.
- One constructor path: `initPackageCatalog` plus `toPackageCatalog`.
- One shared helper for missing ids.
- `tags` gets both `lent` and `var` because callers are allowed to mutate tags.
- `downloads` stays a plain scalar accessor; there is no `var Natural` accessor.
